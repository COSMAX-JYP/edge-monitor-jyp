import AppKit
import SwiftUI

struct ProcessColumn: View {
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

struct ProcessRowView: View {
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
