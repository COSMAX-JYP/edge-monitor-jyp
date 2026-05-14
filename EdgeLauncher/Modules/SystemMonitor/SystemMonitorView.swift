import AppKit
import Darwin
import SwiftUI

struct SystemMonitorView: View {
    @StateObject private var stats = SystemStats()
    @StateObject private var procs = ProcessStats()

    var body: some View {
        VStack(spacing: 0) {
            topGauges
            Divider()
            HStack(spacing: 0) {
                ProcessColumn(title: "CPU", icon: "cpu", accent: .blue, rows: procs.cpuTop, onKill: kill)
                Divider()
                ProcessColumn(title: "Memory", icon: "memorychip", accent: .purple, rows: procs.memTop, onKill: kill)
                Divider()
                ProcessColumn(title: "Energy", icon: "bolt.fill", accent: .orange, rows: procs.energyTop, valueDescription: "누적 CPU 시간", onKill: kill)
                Divider()
                ProcessColumn(title: "Disk", icon: "internaldrive", accent: .teal, rows: procs.diskTop, valueDescription: "활성 스레드 수", onKill: kill)
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
            gauge(title: "CPU", value: stats.cpuCurrent, color: .blue, history: stats.cpuHistory)
            Divider()
            gauge(title: "MEM", value: stats.memCurrent, color: .purple, history: stats.memHistory)
        }
        .frame(height: 180)
    }

    private func gauge(title: String, value: Double, color: Color, history: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", value))
                    .font(.system(size: 32, weight: .light, design: .monospaced))
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

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = max(values.count - 1, 1)

            ZStack {
                ForEach([25.0, 50.0, 75.0], id: \.self) { y in
                    let yPos = h - h * (y / 100.0)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: yPos))
                        p.addLine(to: CGPoint(x: w, y: yPos))
                    }
                    .stroke(.secondary.opacity(0.15), lineWidth: 1)
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(n)
                        let y = h - h * CGFloat(v / 100.0)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.4), color.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                ))

                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(n)
                        let y = h - h * CGFloat(v / 100.0)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, lineWidth: 1.5)
            }
        }
    }
}

private struct ProcessColumn: View {
    let title: String
    let icon: String
    let accent: Color
    let rows: [ProcessRow]
    var valueDescription: String? = nil
    let onKill: (Int, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if let desc = valueDescription {
                    Text(desc)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            if rows.isEmpty {
                VStack {
                    ProgressView().controlSize(.small)
                    Text("샘플링 중...")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                            ProcessRowView(rank: idx + 1, row: row, accent: accent)
                                .contextMenu {
                                    Button("프로세스 정보 복사") {
                                        let text = "\(row.name) (PID \(row.id)) — \(row.value)"
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(text, forType: .string)
                                    }
                                    Divider()
                                    Button("종료 (SIGTERM)") { onKill(row.id, false) }
                                    Button("강제 종료 (SIGKILL)", role: .destructive) { onKill(row.id, true) }
                                }
                            if idx < rows.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProcessRowView: View {
    let rank: Int
    let row: ProcessRow
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 16, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text("PID \(row.id)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(row.value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            GeometryReader { geo in
                Rectangle()
                    .fill(accent.opacity(0.08))
                    .frame(width: geo.size.width * CGFloat(min(row.highlight / 100, 1)))
            }
        )
    }
}
