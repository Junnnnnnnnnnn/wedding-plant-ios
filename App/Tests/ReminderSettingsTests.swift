import XCTest
import WPModels
import WPNetworking
@testable import WeddingPlant

final class ReminderSettingsTests: XCTestCase {
    @MainActor func testFailedAutosaveRestoresConfirmedSetting() async {
        let base = URL(string: "https://example.test")!
        let model = ReminderSettingsModel()
        let before = ReminderSetting(emailAddress: "jisoo@example.com")
        model.setting = before
        let api = APIClient(baseURL: base, transport: FailingReminderTransport(), tokenStore: InMemoryTokenStore(token: DemoData.token))
        var next = before; next.leadDays = [3, 0]
        await model.save(next, api: api)
        XCTAssertEqual(model.setting, before)
        XCTAssertFalse(model.saving); XCTAssertFalse(model.saved); XCTAssertNotNil(model.saveError)
    }
    @MainActor func testSuccessfulAutosavePersistsOnReloadAndRetainsReceiver() async throws {
        let base = URL(string: "https://example.test")!
        let transport = DemoTransport()
        let store = InMemoryTokenStore(token: DemoData.token)
        let api = APIClient(baseURL: base, transport: transport, tokenStore: store)
        let model = ReminderSettingsModel()
        model.setting = try await api.send(Endpoint.reminderSetting())
        var next = try XCTUnwrap(model.setting); next.leadDays = [3, 0]; next.hour = 12; next.email = true
        await model.save(next, api: api)
        XCTAssertEqual(model.setting, next); XCTAssertTrue(model.saved)
        let reloaded: ReminderSetting = try await api.send(Endpoint.reminderSetting())
        XCTAssertEqual(reloaded, next)
    }
}
private actor FailingReminderTransport: HTTPTransport {
    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        HTTPResponse(status: 503, headers: [:], body: Data())
    }
}
