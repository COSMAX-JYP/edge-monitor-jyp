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
            Label("오늘 일정", systemImage: "calendar").font(.appTitle)
            Spacer()
            if eventVM.hasEventAccess {
                Text("\(eventVM.events.count)건").font(.appCalloutMono).foregroundStyle(.secondary)
            }
            Button(action: { eventVM.reloadEvents() }) {
                Image(systemName: "arrow.clockwise").font(.appCallout)
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
                Text(event.title ?? "(제목 없음)").font(.appBodyBold).lineLimit(1)
                HStack(spacing: 6) {
                    Text(timeRange(event)).font(.appCalloutMono).foregroundStyle(.secondary)
                    if let loc = event.location, !loc.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(loc).font(.appCallout).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                if let cal = event.calendar {
                    Text(cal.title).font(.appFootnote).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 7).padding(.horizontal, 12)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func permissionBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "lock.fill").font(.appBodyBold)
            Text("상태: \(eventVM.calendarStatusText)")
                .font(.appCalloutMono)
                .foregroundStyle(.secondary)
            if let error = eventVM.errorMessage {
                Text(error)
                    .font(.appCallout)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            Text("권한 요청 후 거부된 경우에만 시스템 설정의 캘린더 목록에 표시됩니다.")
                .font(.appCallout).foregroundStyle(.secondary)
            Button(eventVM.isRequestingCalendarAccess ? "요청 중..." : "권한 다시 요청") {
                Task { await eventVM.requestCalendarAccess() }
            }
            .font(.appCallout)
            .disabled(eventVM.isRequestingCalendarAccess)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func emptyState(_ title: String, system: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: system).font(.system(size: 32)).foregroundStyle(.green)
            Text(title).font(.appCallout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 24)
    }

    private func timeRange(_ event: EKEvent) -> String {
        if event.isAllDay { return "종일" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(f.string(from: event.startDate)) – \(f.string(from: event.endDate))"
    }
}
