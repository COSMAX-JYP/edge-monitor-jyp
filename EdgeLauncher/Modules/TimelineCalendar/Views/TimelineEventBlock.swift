import SwiftUI

struct TimelineEventBlock: View {
    let placement: EventLayoutEngine.Placement
    let baseColor: Color

    var body: some View {
        let event = placement.event
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if placement.truncatedStart {
                    Image(systemName: "arrowtriangle.left.fill").font(.system(size: 10))
                }
                Text(event.title)
                    .font(.appFootnoteBold)
                    .lineLimit(1)
                if placement.truncatedEnd {
                    Spacer(minLength: 2)
                    Image(systemName: "arrowtriangle.right.fill").font(.system(size: 10))
                }
            }
            Text(timeLabel(start: event.start, end: event.end))
                .font(.appCaptionMono)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(baseColor.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(baseColor.opacity(0.55), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(baseColor)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
        }
        .contentShape(Rectangle())
    }

    private func timeLabel(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start)) — \(formatter.string(from: end))"
    }
}
