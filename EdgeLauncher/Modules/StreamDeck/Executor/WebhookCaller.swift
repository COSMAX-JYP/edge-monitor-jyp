import Foundation

enum WebhookCaller {
    static func call(
        urlString: String,
        method: HTTPMethod,
        headers: [WebhookHeader],
        body: String
    ) async throws -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            throw ActionExecutorError.invalidInput("올바르지 않은 URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        var hasContentType = false
        for header in headers where !header.name.trimmingCharacters(in: .whitespaces).isEmpty {
            request.setValue(header.value, forHTTPHeaderField: header.name)
            if header.name.lowercased() == "content-type" { hasContentType = true }
        }
        if !body.isEmpty {
            request.httpBody = body.data(using: .utf8)
            if !hasContentType, method != .get {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let respBody = String(data: data, encoding: .utf8) ?? "(binary)"
        if (200..<300).contains(status) {
            return "HTTP \(status)\n\(respBody)"
        } else {
            throw ActionExecutorError.webhookFailed("HTTP \(status)\n\(respBody)")
        }
    }
}
