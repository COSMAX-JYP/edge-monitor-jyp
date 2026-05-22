import Foundation
import os

struct Person: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let email: String
    let jobTitle: String?
    let department: String?
}

@MainActor
final class AttendeeSearchService {
    private let auth: MSALAuthService
    private let session: URLSession
    private var cache: [String: [Person]] = [:]
    private var pendingTask: Task<[Person], Error>?

    init(auth: MSALAuthService, session: URLSession = .shared) {
        self.auth = auth
        self.session = session
    }

    func search(query: String) async throws -> [Person] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        AppLog.event.info("AttendeeSearch: query='\(trimmed, privacy: .public)'")
        guard !trimmed.isEmpty else { return [] }
        if let cached = cache[trimmed.lowercased()] {
            AppLog.event.info("AttendeeSearch: cache hit (\(cached.count, privacy: .public))")
            return cached
        }
        guard auth.isSignedIn() else {
            AppLog.event.info("AttendeeSearch: not signed in")
            return []
        }

        pendingTask?.cancel()
        let task = Task { [auth, session] () throws -> [Person] in
            let token = try await auth.acquireAccessToken().accessToken
            var comps = URLComponents(string: "\(OutlookConfig.graphBase)/me/people")!
            comps.queryItems = [
                .init(name: "$search", value: "\"\(trimmed)\""),
                .init(name: "$select", value: "id,displayName,scoredEmailAddresses,jobTitle,department"),
                .init(name: "$top", value: "10"),
            ]
            var req = URLRequest(url: comps.url!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let urlStr = comps.url?.absoluteString ?? "?"
            AppLog.event.info("People GET \(urlStr, privacy: .public)")

            let (data, response) = try await session.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppLog.event.info("People response status=\(status, privacy: .public) bytes=\(data.count, privacy: .public)")
            if status >= 400 {
                let body = String(data: data.prefix(800), encoding: .utf8) ?? ""
                AppLog.event.error("People error body: \(body, privacy: .public)")
                return []
            }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let values = obj["value"] as? [[String: Any]] else { return [] }
            let people: [Person] = values.compactMap { raw in
                let id = raw["id"] as? String ?? UUID().uuidString
                let displayName = raw["displayName"] as? String ?? ""
                let scored = raw["scoredEmailAddresses"] as? [[String: Any]] ?? []
                let email = (scored.first?["address"] as? String) ?? ""
                guard !email.isEmpty else { return nil }
                return Person(
                    id: id,
                    displayName: displayName.isEmpty ? email : displayName,
                    email: email,
                    jobTitle: raw["jobTitle"] as? String,
                    department: raw["department"] as? String
                )
            }
            AppLog.event.info("People parsed \(people.count, privacy: .public) results")
            return people
        }
        pendingTask = task
        let people = try await task.value
        cache[trimmed.lowercased()] = people
        return people
    }
}
