import Foundation
import os

@MainActor
final class AggregatingCalendarProvider: CalendarProvider {
    let source: CalendarSourceKind = .apple
    private let providers: [any CalendarProvider]
    private var calendarOwner: [String: CalendarSourceKind] = [:]
    private(set) var lastErrors: [CalendarSourceKind: Error] = [:]

    init(providers: [any CalendarProvider]) {
        self.providers = providers
    }

    func fetchEvents(on day: Date) async throws -> [TimelineEvent] {
        var all: [TimelineEvent] = []
        lastErrors.removeAll()
        for p in providers {
            let sourceName = String(describing: p.source)
            let dayStr = ISO8601DateFormatter().string(from: day)
            do {
                let chunk = try await p.fetchEvents(on: day)
                AppLog.event.info("[\(sourceName, privacy: .public)] fetched \(chunk.count, privacy: .public) events on \(dayStr, privacy: .public)")
                all.append(contentsOf: chunk)
            } catch {
                lastErrors[p.source] = error
                AppLog.event.error("[\(sourceName, privacy: .public)] fetch failed on \(dayStr, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        if all.isEmpty, let err = lastErrors.values.first { throw err }
        return all
    }

    func availableCalendars() async throws -> [CalendarChoice] {
        var all: [CalendarChoice] = []
        calendarOwner.removeAll()
        for p in providers {
            let list = (try? await p.availableCalendars()) ?? []
            for choice in list {
                calendarOwner[choice.id] = p.source
            }
            all.append(contentsOf: list)
        }
        return all
    }

    func defaultCalendarId() async throws -> String? {
        for p in providers {
            if let id = try? await p.defaultCalendarId() { return id }
        }
        return nil
    }

    func saveEvent(_ draft: EventDraft) async throws -> TimelineEvent {
        let provider = try providerForCalendarId(draft.calendarId)
        return try await provider.saveEvent(draft)
    }

    func updateEvent(_ event: TimelineEvent, draft: EventDraft) async throws -> TimelineEvent {
        let provider = try providerForSource(event.source)
        return try await provider.updateEvent(event, draft: draft)
    }

    func deleteEvent(_ event: TimelineEvent) async throws {
        let provider = try providerForSource(event.source)
        try await provider.deleteEvent(event)
    }

    func findProvider(of kind: CalendarSourceKind) -> (any CalendarProvider)? {
        providers.first { $0.source == kind }
    }

    private func providerForSource(_ source: CalendarSource) throws -> any CalendarProvider {
        let kind: CalendarSourceKind
        switch source {
        case .apple: kind = .apple
        case .outlook: kind = .outlook
        case .local: kind = .local
        }
        guard let p = providers.first(where: { $0.source == kind }) else {
            throw CalendarProviderError.unsupported
        }
        return p
    }

    private func providerForCalendarId(_ calendarId: String) throws -> any CalendarProvider {
        guard let kind = calendarOwner[calendarId] else {
            throw CalendarProviderError.calendarNotFound(identifier: calendarId)
        }
        guard let p = providers.first(where: { $0.source == kind }) else {
            throw CalendarProviderError.unsupported
        }
        return p
    }
}
