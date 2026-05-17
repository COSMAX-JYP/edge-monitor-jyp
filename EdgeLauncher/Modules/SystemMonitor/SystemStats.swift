import Combine
import Darwin
import Foundation
import IOKit

@MainActor
final class SystemStats: ObservableObject {
    @Published var cpuHistory: [Double] = Array(repeating: 0, count: 120)
    @Published var memHistory: [Double] = Array(repeating: 0, count: 120)
    @Published var diskHistory: [Double] = Array(repeating: 0, count: 120)
    @Published var cpuCurrent: Double = 0
    @Published var memCurrent: Double = 0
    @Published var diskCurrentMBps: Double = 0

    private var prevTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) = (0, 0, 0, 0)
    private var prevDiskBytes: (read: UInt64, write: UInt64) = (0, 0)
    private var prevDiskSampleTime: Date = Date()
    private var timer: Timer?

    private static let diskScaleMBps: Double = 500  // 500 MB/s = sparkline 100%

    init() {
        _ = sampleCPU() // 초기 baseline. Timer는 외부 start() 호출 시 시작.
        prevDiskBytes = Self.readDiskBytes()
        prevDiskSampleTime = Date()
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let cpu = sampleCPU()
        let mem = sampleMemory()
        let disk = sampleDisk()
        cpuCurrent = cpu
        memCurrent = mem
        diskCurrentMBps = disk
        cpuHistory.removeFirst()
        cpuHistory.append(cpu)
        memHistory.removeFirst()
        memHistory.append(mem)
        diskHistory.removeFirst()
        diskHistory.append(min(disk / Self.diskScaleMBps * 100.0, 100.0))
    }

    private func sampleDisk() -> Double {
        let current = Self.readDiskBytes()
        let now = Date()
        let elapsed = now.timeIntervalSince(prevDiskSampleTime)
        prevDiskSampleTime = now

        let dRead = current.read &- prevDiskBytes.read
        let dWrite = current.write &- prevDiskBytes.write
        prevDiskBytes = current

        guard elapsed > 0 else { return 0 }
        let bytesPerSec = Double(dRead + dWrite) / elapsed
        return bytesPerSec / (1024 * 1024) // MB/s
    }

    nonisolated private static func readDiskBytes() -> (read: UInt64, write: UInt64) {
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        guard IOServiceGetMatchingServices(0, matching, &iter) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iter) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        while true {
            let svc = IOIteratorNext(iter)
            if svc == 0 { break }
            defer { IOObjectRelease(svc) }

            var propsRef: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(svc, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let cfDict = propsRef?.takeRetainedValue() else { continue }
            let dict = cfDict as NSDictionary
            guard let stats = dict["Statistics"] as? [String: Any] else { continue }
            if let read = stats["Bytes (Read)"] as? UInt64 { totalRead += read }
            if let write = stats["Bytes (Write)"] as? UInt64 { totalWrite += write }
        }
        return (totalRead, totalWrite)
    }

    private func sampleCPU() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { reb in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reb, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = info.cpu_ticks.0
        let system = info.cpu_ticks.1
        let idle = info.cpu_ticks.2
        let nice = info.cpu_ticks.3

        let dUser = user &- prevTicks.user
        let dSystem = system &- prevTicks.system
        let dIdle = idle &- prevTicks.idle
        let dNice = nice &- prevTicks.nice
        prevTicks = (user, system, idle, nice)

        let total = UInt64(dUser) + UInt64(dSystem) + UInt64(dIdle) + UInt64(dNice)
        guard total > 0 else { return 0 }
        let busy = UInt64(dUser) + UInt64(dSystem) + UInt64(dNice)
        return Double(busy) / Double(total) * 100.0
    }

    private func sampleMemory() -> Double {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reb in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reb, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        let used = active + wired + compressed
        let total = ProcessInfo.processInfo.physicalMemory
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100.0
    }
}
