import XCTest
@testable import EdgeLauncher

final class WebhookTemplateTests: XCTestCase {

    func test_presets_nonEmpty() {
        XCTAssertGreaterThan(WebhookTemplate.presets.count, 0)
    }

    func test_presets_haveUniqueIds() {
        let ids = WebhookTemplate.presets.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_presets_haveValidContent() {
        for template in WebhookTemplate.presets {
            XCTAssertFalse(template.id.isEmpty, "id missing")
            XCTAssertFalse(template.name.isEmpty, "name missing in \(template.id)")
            XCTAssertFalse(template.iconSymbol.isEmpty, "icon missing in \(template.id)")
            XCTAssertFalse(template.urlPlaceholder.isEmpty, "url missing in \(template.id)")
        }
    }

    func test_find_byId() {
        XCTAssertNotNil(WebhookTemplate.find(id: "slack"))
        XCTAssertNil(WebhookTemplate.find(id: "non-existent-id"))
    }

    func test_slackPreset_hasJSONContentType() {
        let slack = WebhookTemplate.find(id: "slack")!
        XCTAssertEqual(slack.method, .post)
        XCTAssertTrue(slack.headers.contains { $0.name.lowercased() == "content-type" && $0.value.contains("json") })
    }
}
