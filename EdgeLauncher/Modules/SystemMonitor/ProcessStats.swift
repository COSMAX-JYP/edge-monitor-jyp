import Combine
import Foundation

struct ProcessRow: Identifiable, Hashable {
    let id: Int       // pid
    let name: String
    let value: String
    let highlight: Double // 0~100 정규화 (bar용)
}

@MainActor
final class ProcessStats: ObservableObject {
    @Published var cpuTop: [ProcessRow] = []
    @Published var memTop: [ProcessRow] = []
    @Published var energyTop: [ProcessRow] = []
    @Published var diskTop: [ProcessRow] = []

    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?

    init() {
        // 초기 데이터는 비동기로. main thread blocking 회피 (macOS 26+ abort 방지).
        refresh()
    }

    deinit {
        timer?.invalidate()
        refreshTask?.cancel()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task.detached(priority: .userInitiated) {
            let cpu = Self.parseCPU()
            let mem = Self.parseMemory()
            let energy = Self.parseEnergy()
            let disk = Self.parseDisk()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.refreshTask = nil
                guard !Task.isCancelled else { return }
                self.cpuTop = cpu
                self.memTop = mem
                self.energyTop = energy
                self.diskTop = disk
            }
        }
    }

    // MARK: - parsers (nonisolated: no instance state; run on background thread)

    nonisolated private static func parseCPU() -> [ProcessRow] {
        let raw = run("ps -axo pid=,pcpu=,comm= -r | head -10")
        let rows = lines(raw).compactMap { line -> ProcessRow? in
            let parts = tokens(line, max: 3)
            guard parts.count >= 3,
                  let pid = Int(parts[0]),
                  let cpu = Double(parts[1]) else { return nil }
            return ProcessRow(
                id: pid,
                name: prettyName(parts[2]),
                value: String(format: "%.1f%%", cpu),
                highlight: min(cpu, 100)
            )
        }
        return rows
    }

    nonisolated private static func parseMemory() -> [ProcessRow] {
        let raw = run("ps -axo pid=,rss=,comm= -m | head -10")
        let rows = lines(raw).compactMap { line -> ProcessRow? in
            let parts = tokens(line, max: 3)
            guard parts.count >= 3,
                  let pid = Int(parts[0]),
                  let rssKB = Double(parts[1]) else { return nil }
            let mb = rssKB / 1024
            return ProcessRow(
                id: pid,
                name: prettyName(parts[2]),
                value: mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.0f MB", mb),
                highlight: min(mb / 100, 100)
            )
        }
        return rows
    }

    nonisolated private static func parseEnergy() -> [ProcessRow] {
        // ps의 누적 CPU time (cputime)를 에너지 임팩트 근사값으로 사용.
        let raw = run("ps -axo pid=,time=,comm= | sort -k2 -r | head -10")
        let rows = lines(raw).compactMap { line -> ProcessRow? in
            let parts = tokens(line, max: 3)
            guard parts.count >= 3, let pid = Int(parts[0]) else { return nil }
            return ProcessRow(
                id: pid,
                name: prettyName(parts[2]),
                value: parts[1],
                highlight: 0
            )
        }
        return rows
    }

    nonisolated private static func parseDisk() -> [ProcessRow] {
        // macOS ps 가 디스크 I/O 컬럼을 노출하지 않는다.
        // 대안: 가장 많은 스레드를 가진 프로세스 (대용량 작업의 간접 지표) 또는 placeholder.
        let raw = run("ps -axo pid=,nlwp=,comm= | sort -k2 -nr | head -10")
        let rows = lines(raw).compactMap { line -> ProcessRow? in
            let parts = tokens(line, max: 3)
            guard parts.count >= 3,
                  let pid = Int(parts[0]),
                  let threads = Int(parts[1]) else { return nil }
            return ProcessRow(
                id: pid,
                name: prettyName(parts[2]),
                value: "\(threads) 스레드",
                highlight: min(Double(threads), 100)
            )
        }
        return rows
    }

    // MARK: - helpers

    nonisolated private static func lines(_ s: String) -> [String] {
        s.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    nonisolated private static func tokens(_ line: String, max: Int) -> [String] {
        var result: [String] = []
        var remaining = line.trimmingCharacters(in: .whitespaces)
        for i in 0..<max {
            if i == max - 1 {
                result.append(remaining)
                break
            }
            if let range = remaining.rangeOfCharacter(from: .whitespaces) {
                result.append(String(remaining[..<range.lowerBound]))
                remaining = String(remaining[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                result.append(remaining)
                break
            }
        }
        return result
    }

    nonisolated private static func prettyName(_ raw: String) -> String {
        // 풀 경로면 마지막 컴포넌트만 사용
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("/") {
            return String(trimmed.split(separator: "/").last ?? Substring(trimmed))
        }
        return trimmed
    }

    nonisolated private static func run(_ cmd: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", cmd]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
