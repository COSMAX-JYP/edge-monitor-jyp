import EventKit
import SwiftUI

struct OutlookPanel: View {
    @ObservedObject var eventVM: EventStoreVM

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !eventVM.hasEventAccess {
                permissionBanner(message: "캘린더 권한이 필요합니다")
            } else if eventVM.events.isEmpty {
                emptyState("오늘 일정 없음", system: "checkmark.circle")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(eventVM.events, id: \.eventIdentifier) { eventRow($0) }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Label("오늘 일정", systemImage: "calendar").font(.system(size: 18, weight: .semibold))
            Spacer()
            if eventVM.hasEventAccess {
                Text("\(eventVM.events.count)건").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            }
            Button(action: { eventVM.reloadEvents() }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(cgColor: event.calendar?.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1, alpha: 1)))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "(제목 없음)").font(.system(size: 16, weight: .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(timeRange(event)).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    if let loc = event.location, !loc.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(loc).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if let cal = event.calendar {
                    Text(cal.title).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func permissionBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "lock.fill").font(.system(size: 14, weight: .semibold))
            Text("시스템 설정 > 개인정보 보호 및 보안에서 EdgeLauncher 허용.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Button("권한 다시 요청") { Task { await eventVM.requestAccess() } }.controlSize(.small)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func emptyState(_ title: String, system: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: system).font(.system(size: 32)).foregroundStyle(.green)
            Text(title).font(.system(size: 14)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 24)
    }

    private func timeRange(_ event: EKEvent) -> String {
        if event.isAllDay { return "종일" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }
}
