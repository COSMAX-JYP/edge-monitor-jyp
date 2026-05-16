import SwiftUI

struct EventEditorSheet: View {
    let initial: EventDraft
    let calendars: [CalendarChoice]
    let isNew: Bool
    var onSave: (EventDraft) async -> Void
    var onCancel: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var location: String
    @State private var start: Date
    @State private var end: Date
    @State private var isAllDay: Bool
    @State private var calendarId: String
    @State private var isSaving: Bool = false

    init(
        initial: EventDraft,
        calendars: [CalendarChoice],
        isNew: Bool,
        onSave: @escaping (EventDraft) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initial = initial
        self.calendars = calendars
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: initial.title)
        _notes = State(initialValue: initial.notes)
        _location = State(initialValue: initial.location)
        _start = State(initialValue: initial.start)
        _end = State(initialValue: initial.end)
        _isAllDay = State(initialValue: initial.isAllDay)
        _calendarId = State(initialValue: initial.calendarId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(isNew ? "새 일정" : "일정 편집").font(.appTitle)
                Spacer()
                Button("취소", action: onCancel).font(.appBody)
                Button(isNew ? "추가" : "저장") {
                    Task { await save() }
                }
                .font(.appBodyBold)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!isValid || isSaving)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("제목").font(.appFootnote).foregroundStyle(.secondary)
                TextField("필수", text: $title)
                    .font(.appBody)
                    .textFieldStyle(.roundedBorder)
            }
            calendarSection
            timingSection
            VStack(alignment: .leading, spacing: 6) {
                Text("위치").font(.appFootnote).foregroundStyle(.secondary)
                TextField("(옵션)", text: $location)
                    .font(.appBody)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("노트").font(.appFootnote).foregroundStyle(.secondary)
                TextEditor(text: $notes)
                    .font(.appBody)
                    .frame(minHeight: 120, maxHeight: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            }
            if isSaving {
                HStack { ProgressView().controlSize(.small); Text("저장 중...").font(.appFootnote) }
            }
            Spacer()
        }
        .padding(24)
        .appSheetFrame(width: 0.5...0.8, height: 0.55...0.85)
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("캘린더").font(.appFootnote).foregroundStyle(.secondary)
            Picker("", selection: $calendarId) {
                ForEach(calendars.filter { $0.allowsModifications }) { cal in
                    HStack {
                        if let hex = cal.colorHex, let color = Color.fromHex(hex) {
                            Circle().fill(color).frame(width: 10, height: 10)
                        }
                        Text("\(cal.title) — \(cal.sourceTitle)")
                    }
                    .tag(cal.id)
                }
            }
            .font(.appBody)
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("종일", isOn: $isAllDay).font(.appBody)
                Spacer()
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("시작").font(.appFootnote).foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $start,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .font(.appBody)
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("종료").font(.appFootnote).foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $end,
                        in: start...,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .font(.appBody)
                    .labelsHidden()
                }
            }
            .onChange(of: start) { _, newStart in
                if end <= newStart {
                    end = newStart.addingTimeInterval(3600)
                }
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !calendarId.isEmpty
            && (isAllDay || end > start)
    }

    private func save() async {
        isSaving = true
        var draft = initial
        draft.title = title.trimmingCharacters(in: .whitespaces)
        draft.notes = notes
        draft.location = location.trimmingCharacters(in: .whitespaces)
        draft.start = start
        draft.end = end
        draft.isAllDay = isAllDay
        draft.calendarId = calendarId
        await onSave(draft)
        isSaving = false
    }
}
