import Foundation
import IOKit
import IOKit.hid
import CoreGraphics
import AppKit

/// Corsair Xeneon Edge 터치스크린 raw HID 캡처 + Edge 디스플레이 좌표로 변환 → CGEvent 합성.
/// 구현 패턴은 ymlaine/TouchscreenDriver 오픈소스를 참고했다.
/// macOS 기본 드라이버가 터치를 메인 모니터로 잘못 매핑하므로
/// SeizeDevice 로 점유 → raw X/Y/Button 직접 파싱 → 정확한 Edge 좌표로 클릭 합성.
final class CorsairHIDCapture {
    static let touchVendorID = 0x27C0   // wch.cn — Edge 터치 패널 제조사
    static let touchProductID = 0x0859

    // 터치스크린 원시 좌표 범위 (드라이버 분석값).
    static let touchMaxX: CGFloat = 16383
    static let touchMaxY: CGFloat = 9599

    private var manager: IOHIDManager?
    private var currentX: CGFloat = 0
    private var currentY: CGFloat = 0
    private var isTouching: Bool = false
    private var lastClickTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.05

    private let displayService: XeneonDisplayService?

    init(displayService: XeneonDisplayService? = nil) {
        self.displayService = displayService
    }

    func start() {
        guard manager == nil else { return }

        // 입력 모니터링 + 이벤트 합성(Accessibility) 두 권한 모두 필요.
        let listenAccess = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        Self.log("IOHIDRequestAccess(listen)   = \(listenAccess)")
        let postAccess = IOHIDRequestAccess(kIOHIDRequestTypePostEvent)
        Self.log("IOHIDRequestAccess(postEvent)= \(postAccess)")
        let axTrusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        Self.log("AXIsProcessTrusted = \(axTrusted) (Accessibility 권한 — 클릭 합성에 필수)")

        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDVendorIDKey: Self.touchVendorID,
            kIOHIDProductIDKey: Self.touchProductID
        ]
        IOHIDManagerSetDeviceMatching(m, match as CFDictionary)

        let openResult = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        Self.log("manager open(seize) result=\(Self.ioReturnName(openResult))")
        if openResult != kIOReturnSuccess {
            Self.log("Hint: 접근성/입력 모니터링 권한 확인 필요. 시스템 설정 → 개인정보 보호 및 보안 → 접근성/입력 모니터링")
            // 그래도 매니저 등록은 유지 (디바이스 도착 콜백은 받을 수 있음)
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(m, { ctx, _, _, value in
            guard let ctx else { return }
            let me = Unmanaged<CorsairHIDCapture>.fromOpaque(ctx).takeUnretainedValue()
            me.handleValue(value)
        }, context)

        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        IOHIDManagerRegisterDeviceMatchingCallback(m, { ctx, _, _, device in
            guard let ctx else { return }
            let me = Unmanaged<CorsairHIDCapture>.fromOpaque(ctx).takeUnretainedValue()
            let name = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? "?"
            CorsairHIDCapture.log("device matched: \(name)")
            _ = me
        }, context)

        manager = m
        Self.log("manager scheduled (vid=0x\(String(Self.touchVendorID, radix: 16)) pid=0x\(String(Self.touchProductID, radix: 16)))")

        if let devices = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice> {
            Self.log("matched device count = \(devices.count)")
            for d in devices {
                let name = (IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String) ?? "?"
                Self.log("  matched: \(name)")
            }
        } else {
            Self.log("IOHIDManagerCopyDevices returned nil")
        }
    }

    func stop() {
        guard let m = manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = nil
    }

    private var valueLogCount: Int = 0
    private let valueLogLimit: Int = 80

    private func handleValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)

        if valueLogCount < valueLogLimit {
            valueLogCount += 1
            Self.log("value page=0x\(String(page, radix: 16)) usage=0x\(String(usage, radix: 16)) value=\(intValue)")
            if valueLogCount == valueLogLimit {
                Self.log("(value log limit reached)")
            }
        }

        // Generic Desktop / X / Y
        if page == 0x01 {
            switch usage {
            case 0x30: currentX = CGFloat(intValue)
            case 0x31: currentY = CGFloat(intValue)
            default: break
            }
        }

        // 터치 버튼: Button page (0x09) usage 1 OR Digitizer (0x0D) usage 0x42 (Tip Switch)
        let isTouchTransition = (page == 0x09 && usage == 0x01) || (page == 0x0D && usage == 0x42)
        if isTouchTransition {
            let wasTouching = isTouching
            isTouching = intValue != 0
            if isTouching && !wasTouching {
                emitClick()
            } else if isTouching && wasTouching {
                emitDrag()
            }
        }
    }

    private func currentEdgeFrame() -> CGRect? {
        if let s = displayService?.edgeScreen { return s.frame }
        // fallback: 가장 마지막에 매칭된 Edge-shape 디스플레이
        return NSScreen.screens.first { abs($0.frame.width - 2560) <= 4 && abs($0.frame.height - 720) <= 4 }?.frame
    }

    private func mapTouchToScreenPoint() -> CGPoint? {
        guard let edgeFrame = currentEdgeFrame() else { return nil }
        let normX = max(0, min(1, currentX / Self.touchMaxX))
        let normY = max(0, min(1, currentY / Self.touchMaxY))
        // 패널은 Y=0 이 물리적 화면 위쪽, Y=max 가 아래쪽.
        // AppKit 은 Y-up 이라 화면의 물리적 위쪽이 maxY, 아래쪽이 minY.
        let appKitX = edgeFrame.minX + normX * edgeFrame.width
        let appKitY = edgeFrame.maxY - normY * edgeFrame.height
        // AppKit → CG (Y flip, origin = main display top-left)
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: appKitX, y: mainHeight - appKitY)
    }

    /// 클릭 직전 커서 위치 (Quartz 좌표) — 클릭 후 원복용.
    private var savedCursorCG: CGPoint?

    private func emitClick() {
        let now = Date()
        guard now.timeIntervalSince(lastClickTime) > debounceInterval else { return }
        lastClickTime = now

        guard let point = mapTouchToScreenPoint() else { return }
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
            return
        }

        // 1. 현재 커서 위치 저장 (AppKit → CG 변환).
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let appKitCursor = NSEvent.mouseLocation
        let cgCursor = CGPoint(x: appKitCursor.x, y: mainHeight - appKitCursor.y)
        savedCursorCG = cgCursor

        // 2. 클릭 동안 커서 깜빡임 방지를 위해 잠시 숨김.
        CGDisplayHideCursor(CGMainDisplayID())
        CGWarpMouseCursorPosition(point)
        usleep(5_000)
        down.post(tap: .cghidEventTap)
        usleep(10_000)
        up.post(tap: .cghidEventTap)
        usleep(5_000)

        // 3. 원래 위치로 복귀 + 커서 다시 보이기.
        CGWarpMouseCursorPosition(cgCursor)
        CGDisplayShowCursor(CGMainDisplayID())

        if UserDefaults.standard.bool(forKey: "app.debugHIDLogging") {
            Self.log("click @ (\(Int(point.x)),\(Int(point.y))) from touch=(\(Int(currentX)),\(Int(currentY))) restored to (\(Int(cgCursor.x)),\(Int(cgCursor.y)))")
        }
    }

    private func emitDrag() {
        // 드래그 중에는 원복하면 의미가 없으므로 그대로 둔다.
        // (현 구현은 첫 터치에서 click+up 까지 다 보내므로 드래그는 실질 동작 안 함 —
        // 향후 down-on-touch + up-on-release 흐름으로 개선 가능.)
    }

    static func log(_ message: String) {
        let line = "[hid] \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
        if let h = logHandle {
            _ = try? h.seekToEnd()
            _ = try? h.write(contentsOf: Data(line.utf8))
        }
    }

    private static let logFileURL: URL = {
        let url = URL(fileURLWithPath: "/tmp/edgelauncher-hid.log")
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        return url
    }()
    private static let logHandle: FileHandle? = try? FileHandle(forWritingTo: logFileURL)

    static func ioReturnName(_ code: IOReturn) -> String {
        switch code {
        case kIOReturnSuccess: return "success"
        case kIOReturnNotPermitted: return "notPermitted"
        case kIOReturnNotPrivileged: return "notPrivileged"
        case kIOReturnExclusiveAccess: return "exclusiveAccess"
        case kIOReturnNoDevice: return "noDevice"
        case kIOReturnUnsupported: return "unsupported"
        case kIOReturnError: return "generalError"
        default: return "0x\(String(code, radix: 16))"
        }
    }
}
