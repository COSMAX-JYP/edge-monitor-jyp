import SwiftUI

struct ErrorBanner: View {
    @ObservedObject var bus: ErrorBus

    var body: some View {
        if let err = bus.current {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(err.category)
                        .font(.appFootnoteBold)
                    Text(err.message)
                        .font(.appFootnote)
                        .lineLimit(2)
                }
                Spacer()
                Button(action: { bus.dismiss() }) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.yellow.opacity(0.18))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
