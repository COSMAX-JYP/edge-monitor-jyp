import SwiftUI

struct EventEditorSheet: View {
    let initial: EventDraft
    let calendars: [CalendarChoice]
    let isNew: Bool
    let attendeeSearchService: AttendeeSearchService?
    var onSave: (EventDraft) async -> Void
    var onCancel: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var location: String
    @State private var start: Date
    @State private var end: Date
    @State private var isAllDay: Bool
    @State private var calendarId: String
    @State private var attendees: [Attendee]
    @State private var isOnlineMeeting: Bool
    @State private var responseRequested: Bool
    @State private var allowNewTimeProposals: Bool
    @State private var reminderMinutes: Int?
    @State private var importance: EventImportance
    @State private var sensitivity: EventSensitivity
    @State private var showAs: EventShowAs
    @State private var categories: [String]
    @State private var newCategoryText: String = ""
    @State private var recurrence: RecurrencePattern?
    @State private var isSaving: Bool = false
    @State private var expandAdvanced: Bool = false

    init(
        initial: EventDraft,
        calendars: [CalendarChoice],
        isNew: Bool,
        attendeeSearchService: AttendeeSearchService?,
        onSave: @escaping (EventDraft) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initial = initial
        self.calendars = calendars
        self.isNew = isNew
        self.attendeeSearchService = attendeeSearchService
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: initial.title)
        _notes = State(initialValue: initial.notes)
        _location = State(initialValue: initial.location)
        _start = State(initialValue: initial.start)
        _end = State(initialValue: initial.end)
        _isAllDay = State(initialValue: initial.isAllDay)
        _calendarId = State(initialValue: initial.calendarId)
        _attendees = State(initialValue: initial.attendees)
        _isOnlineMeeting = State(initialValue: initial.isOnlineMeeting)
        _responseRequested = State(initialValue: initial.responseRequested)
        _allowNewTimeProposals = State(initialValue: initial.allowNewTimeProposals)
        _reminderMinutes = State(initialValue: initial.reminderMinutesBeforeStart)
        _importance = State(initialValue: initial.importance)
        _sensitivity = State(initialValue: initial.sensitivity)
        _showAs = State(initialValue: initial.showAs)
        _categories = State(initialValue: initial.categories)
        _recurrence = State(initialValue: initial.recurrence)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                titleSection
                calendarSection
                timingSection
                locationSection
                attendeesSection
                notesSection
                advancedSection
                if isSaving {
                    HStack { ProgressView().controlSize(.small); Text("저장 중...").font(.appFootnote) }
                }
            }
            .padding(24)
        }
        .appSheetFrame(width: 0.5...0.85, height: 0.6...0.92)
    }

    private var header: some View {
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
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("제목").font(.appFootnote).foregroundStyle(.secondary)
            TextField("필수", text: $title).font(.appBody).textFieldStyle(.roundedBorder)
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("캘린더").font(.appFootnote).foregroundStyle(.secondary)
            Picker("", selection: $calendarId) {
                ForEach(sortedCalendars) { cal in
                    HStack {
                        if let hex = cal.colorHex, let color = Color.fromHex(hex) {
                            Circle().fill(color).frame(width: 10, height: 10)
                        }
                        Text("\(cal.title) — \(cal.sourceTitle)")
                    }
                    .tag(cal.id)
                }
            }
            .font(.appBody).pickerStyle(.menu).labelsHidden()
            if attendeesWillNotBeInvited {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("선택한 캘린더(iCloud/Apple)는 참석자 초대 이메일을 보내지 않습니다. Outlook 캘린더로 변경하세요.")
                        .font(.appCaption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var sortedCalendars: [CalendarChoice] {
        calendars
            .filter { $0.allowsModifications }
            .sorted { a, b in
                let aOutlook = a.providerKind == .outlook
                let bOutlook = b.providerKind == .outlook
                if aOutlook != bOutlook { return aOutlook && !bOutlook }
                return a.title < b.title
            }
    }

    private var attendeesWillNotBeInvited: Bool {
        guard !attendees.isEmpty else { return false }
        guard let selected = calendars.first(where: { $0.id == calendarId }) else { return false }
        return selected.providerKind != .outlook
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Toggle("종일", isOn: $isAllDay).font(.appBody); Spacer() }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("시작").font(.appFootnote).foregroundStyle(.secondary)
                    DatePicker("", selection: $start, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .font(.appBody).labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("종료").font(.appFootnote).foregroundStyle(.secondary)
                    DatePicker("", selection: $end, in: start..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .font(.appBody).labelsHidden()
                }
            }
            .onChange(of: start) { _, newStart in
                if end <= newStart { end = newStart.addingTimeInterval(3600) }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("위치").font(.appFootnote).foregroundStyle(.secondary)
            HStack {
                TextField("(옵션)", text: $location).font(.appBody).textFieldStyle(.roundedBorder)
                if attendeeSearchService != nil {
                    Toggle(isOn: $isOnlineMeeting) {
                        Label("Teams", systemImage: "video.fill").font(.appFootnote)
                    }
                    .toggleStyle(.button)
                }
            }
        }
    }

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("참석자").font(.appFootnote).foregroundStyle(.secondary)
                Spacer()
                Toggle("응답 요청", isOn: $responseRequested).font(.appCaption)
                Toggle("새 시간 제안 허용", isOn: $allowNewTimeProposals).font(.appCaption)
            }
            AttendeePickerView(attendees: $attendees, searchService: attendeeSearchService)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("노트").font(.appFootnote).foregroundStyle(.secondary)
            TextEditor(text: $notes)
                .font(.appBody)
                .frame(minHeight: 90, maxHeight: 200)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
        }
    }

    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $expandAdvanced) {
            VStack(alignment: .leading, spacing: 12) {
                reminderRow
                recurrenceRow
                HStack {
                    importancePicker
                    showAsPicker
                    sensitivityPicker
                }
                categoriesRow
            }
            .padding(.top, 8)
        } label: {
            Text("고급 옵션").font(.appBodyBold)
        }
    }

    private var reminderRow: some View {
        HStack {
            Text("알림").font(.appFootnote).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            Picker("", selection: Binding(
                get: { reminderMinutes ?? -1 },
                set: { reminderMinutes = ($0 == -1) ? nil : $0 }
            )) {
                Text("없음").tag(-1)
                Text("0분").tag(0)
                Text("5분 전").tag(5)
                Text("10분 전").tag(10)
                Text("15분 전").tag(15)
                Text("30분 전").tag(30)
                Text("1시간 전").tag(60)
                Text("하루 전").tag(1440)
            }
            .labelsHidden().pickerStyle(.menu).fixedSize()
        }
    }

    private var recurrenceRow: some View {
        HStack(alignment: .top) {
            Text("반복").font(.appFootnote).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Picker("", selection: Binding<RecurrencePattern.Frequency?>(
                    get: { recurrence?.frequency },
                    set: { newFreq in
                        if let freq = newFreq {
                            recurrence = RecurrencePattern(frequency: freq, interval: recurrence?.interval ?? 1, daysOfWeek: recurrence?.daysOfWeek ?? [], end: recurrence?.end ?? .never)
                        } else {
                            recurrence = nil
                        }
                    }
                )) {
                    Text("반복 안 함").tag(RecurrencePattern.Frequency?.none)
                    ForEach(RecurrencePattern.Frequency.allCases, id: \.self) { freq in
                        Text(freq.displayName).tag(RecurrencePattern.Frequency?.some(freq))
                    }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
                if let rec = recurrence, rec.frequency == .weekly {
                    weekdayPicker
                }
                if recurrence != nil {
                    recurrenceEndPicker
                }
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 4) {
            ForEach(RecurrencePattern.Weekday.allCases, id: \.self) { day in
                let included = recurrence?.daysOfWeek.contains(day) ?? false
                Button {
                    guard var rec = recurrence else { return }
                    if included {
                        rec.daysOfWeek.removeAll { $0 == day }
                    } else {
                        rec.daysOfWeek.append(day)
                    }
                    recurrence = rec
                } label: {
                    Text(day.displayName)
                        .font(.appCaption)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(included ? Color.accentColor.opacity(0.3) : Color.clear))
                        .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recurrenceEndPicker: some View {
        HStack(spacing: 6) {
            Text("종료").font(.appCaption).foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: {
                    switch recurrence?.end {
                    case .never: return 0
                    case .occurrences: return 1
                    case .onDate: return 2
                    default: return 0
                    }
                },
                set: { newVal in
                    guard var rec = recurrence else { return }
                    switch newVal {
                    case 0: rec.end = .never
                    case 1: rec.end = .occurrences(10)
                    case 2: rec.end = .onDate(start.addingTimeInterval(60 * 60 * 24 * 30))
                    default: rec.end = .never
                    }
                    recurrence = rec
                }
            )) {
                Text("무한").tag(0)
                Text("N회 후").tag(1)
                Text("날짜까지").tag(2)
            }
            .labelsHidden().pickerStyle(.segmented).fixedSize()
        }
    }

    private var importancePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("중요도").font(.appCaption).foregroundStyle(.secondary)
            Picker("", selection: $importance) {
                ForEach(EventImportance.allCases, id: \.self) { imp in
                    Text(imp.displayName).tag(imp)
                }
            }.labelsHidden().pickerStyle(.menu).fixedSize()
        }
    }

    private var showAsPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("표시").font(.appCaption).foregroundStyle(.secondary)
            Picker("", selection: $showAs) {
                ForEach(EventShowAs.allCases, id: \.self) { v in
                    Text(v.displayName).tag(v)
                }
            }.labelsHidden().pickerStyle(.menu).fixedSize()
        }
    }

    private var sensitivityPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("민감도").font(.appCaption).foregroundStyle(.secondary)
            Picker("", selection: $sensitivity) {
                ForEach(EventSensitivity.allCases, id: \.self) { v in
                    Text(v.displayName).tag(v)
                }
            }.labelsHidden().pickerStyle(.menu).fixedSize()
        }
    }

    private var categoriesRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("카테고리").font(.appCaption).foregroundStyle(.secondary)
            HStack {
                ForEach(Array(categories.enumerated()), id: \.offset) { idx, cat in
                    HStack(spacing: 2) {
                        Text(cat).font(.appCaption)
                        Button { categories.remove(at: idx) } label: {
                            Image(systemName: "xmark.circle.fill").font(.appCaption).foregroundStyle(.secondary)
                        }.buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(.tertiary))
                }
                TextField("+추가", text: $newCategoryText)
                    .font(.appCaption)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onSubmit {
                        let t = newCategoryText.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty, !categories.contains(t) { categories.append(t) }
                        newCategoryText = ""
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
        draft.attendees = attendees
        draft.isOnlineMeeting = isOnlineMeeting
        draft.responseRequested = responseRequested
        draft.allowNewTimeProposals = allowNewTimeProposals
        draft.reminderMinutesBeforeStart = reminderMinutes
        draft.importance = importance
        draft.sensitivity = sensitivity
        draft.showAs = showAs
        draft.categories = categories
        draft.recurrence = recurrence
        await onSave(draft)
        isSaving = false
    }
}
