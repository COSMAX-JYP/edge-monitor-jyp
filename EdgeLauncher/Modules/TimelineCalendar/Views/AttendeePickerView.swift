import SwiftUI

struct AttendeePickerView: View {
    @Binding var attendees: [Attendee]
    let searchService: AttendeeSearchService?

    @State private var queryText: String = ""
    @State private var searchResults: [Person] = []
    @State private var isSearching: Bool = false
    @State private var showResults: Bool = false
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(Array(attendees.enumerated()), id: \.offset) { idx, attendee in
                    attendeeChip(idx: idx, attendee: attendee)
                }
            }

            HStack(spacing: 6) {
                TextField("이메일 입력 후 Enter (people.read 권한 시 자동완성)", text: $queryText)
                    .font(.appBody)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: queryText) { _, newValue in
                        scheduleSearch(query: newValue)
                    }
                    .onSubmit { addRawIfEmail(queryText) }
                Button("추가") { addRawIfEmail(queryText) }
                    .disabled(!queryText.contains("@"))
            }

            if showResults {
                VStack(spacing: 0) {
                    if isSearching {
                        HStack { ProgressView().controlSize(.small); Text("검색 중…").font(.appCaption) }
                            .padding(8)
                    } else if searchResults.isEmpty {
                        Text("결과 없음. 이메일 직접 입력 가능.")
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    } else {
                        ForEach(searchResults, id: \.id) { person in
                            personRow(person: person)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.3)))
            }
        }
    }

    private func attendeeChip(idx: Int, attendee: Attendee) -> some View {
        HStack(spacing: 4) {
            Image(systemName: attendee.type == .required ? "person.fill" : "person")
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Text(attendee.name.isEmpty ? attendee.email : attendee.name)
                .font(.appCaption)
            Button {
                attendees.remove(at: idx)
            } label: {
                Image(systemName: "xmark.circle.fill").font(.appCaption).foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.4)))
    }

    private func personRow(person: Person) -> some View {
        Button {
            select(person: person)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.displayName).font(.appBody)
                    Text(person.email).font(.appCaption).foregroundStyle(.secondary)
                    if let title = person.jobTitle, !title.isEmpty {
                        Text(title).font(.appCaption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func scheduleSearch(query: String) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            searchResults = []
            showResults = false
            return
        }
        showResults = true
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            if Task.isCancelled { return }
            isSearching = true
            defer { isSearching = false }
            guard let svc = searchService else {
                searchResults = []
                return
            }
            do {
                let results = try await svc.search(query: trimmed)
                if Task.isCancelled { return }
                let existingEmails = Set(attendees.map { $0.email.lowercased() })
                searchResults = results.filter { !existingEmails.contains($0.email.lowercased()) }
            } catch {
                searchResults = []
            }
        }
    }

    private func select(person: Person) {
        let attendee = Attendee(name: person.displayName, email: person.email, response: .needsAction, isOrganizer: false, type: .required)
        attendees.append(attendee)
        queryText = ""
        searchResults = []
        showResults = false
    }

    private func addRawIfEmail(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@") else { return }
        let existing = Set(attendees.map { $0.email.lowercased() })
        guard !existing.contains(trimmed.lowercased()) else { queryText = ""; return }
        attendees.append(Attendee(name: "", email: trimmed, response: .needsAction, isOrganizer: false, type: .required))
        queryText = ""
        searchResults = []
        showResults = false
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > width {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
