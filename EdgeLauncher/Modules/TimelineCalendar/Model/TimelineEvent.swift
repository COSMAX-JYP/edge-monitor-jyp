import Foundation

struct TimelineEvent: Identifiable, Hashable, Sendable {
    let id: String
    var source: CalendarSource
    var calendarItemIdentifier: String
    var occurrenceStart: Date
    var title: String
    var notes: String?
    var location: String?
    var start: Date
    var end: Date
    var isAllDay: Bool
    var attendees: [Attendee]
    var colorHex: String?
    var lastModified: Date
    var url: URL?

    init(
        source: CalendarSource,
        calendarItemIdentifier: String,
        occurrenceStart: Date,
        title: String,
        notes: String? = nil,
        location: String? = nil,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        attendees: [Attendee] = [],
        colorHex: String? = nil,
        lastModified: Date = Date(),
        url: URL? = nil
    ) {
        self.source = source
        self.calendarItemIdentifier = calendarItemIdentifier
        self.occurrenceStart = occurrenceStart
        self.title = title
        self.notes = notes
        self.location = location
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.attendees = attendees
        self.colorHex = colorHex
        self.lastModified = lastModified
        self.url = url
        self.id = TimelineEvent.makeId(source: source, itemId: calendarItemIdentifier, occurrence: occurrenceStart)
    }

    static func makeId(source: CalendarSource, itemId: String, occurrence: Date) -> String {
        let occurrenceInt = Int(occurrence.timeIntervalSince1970)
        return "\(source.key)|\(itemId)|\(occurrenceInt)"
    }

    func duration() -> TimeInterval { end.timeIntervalSince(start) }
}
