import AppKit
import Darwin
import SwiftUI

struct SystemMonitorView: View {
    @ObservedObject var stats: SystemStats
    @ObservedObject var procs: ProcessStats

    var body: some View {
        VStack(spacing: 0) {
            topGauges
            Divider()
            HStack(spacing: 0) {
                ProcessColumn(title: "CPU", icon: "cpu", accent: .blue, rows: procs.cpuTop, valueDescription: "현재 사용률", onKill: kill)
                Divider()
                ProcessColumn(title: "Memory", icon: "memorychip", accent: .purple, rows: procs.memTop, valueDescription: "물리 메모리 (RSS)", onKill: kill)
                Divider()
                ProcessColumn(title: "Energy", icon: "bolt.fill", accent: .orange, rows: procs.energyTop, valueDescription: "누적 CPU 시간", onKill: kill)
                Divider()
                ProcessColumn(title: "Disk", icon: "internaldrive", accent: .teal, rows: procs.diskTop, valueDescription: "누적 페이지인 (디스크→RAM)", onKill: kill)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func kill(_ pid: Int, force: Bool) {
        let signal = force ? SIGKILL : SIGTERM
        let result = Darwin.kill(pid_t(pid), signal)
        if result != 0 {
            let alert = NSAlert()
            alert.messageText = "프로세스 종료 실패"
            alert.informativeText = "PID \(pid) (errno \(errno)). 권한이 없을 수 있습니다 (root/SIP 보호)."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "확인")
            alert.runModal()
        }
        procs.refresh()
    }

    private var topGauges: some View {
        HStack(spacing: 0) {
            gauge(title: "CPU", value: stats.cpuCurrent, color: .blue, history: stats.cpuHistory, format: "%.1f%%")
            Divider()
            gauge(title: "MEM", value: stats.memCurrent, color: .purple, history: stats.memHistory, format: "%.1f%%")
            Divider()
            gauge(title: "DISK", value: stats.diskCurrentMBps, color: .teal, history: stats.diskHistory, format: "%.1f MB/s")
        }
        .frame(height: 180)
    }

    private func gauge(title: String, value: Double, color: Color, history: [Double], format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(title)
                    .font(.appBodyMonoBold)
                    .foregroundStyle(.secondary)
                Text(String(format: format, value))
                    .font(.system(size: 42, weight: .light, design: .monospaced))
                    .contentTransition(.numericText(value: value))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Sparkline(values: history, color: color)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
