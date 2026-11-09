import XCTest
@testable import WPNetworking

final class GuestbookEndpointTests: XCTestCase {
    func testOwnerGuestbookRequests() throws {
        let list = Endpoint.myGuestbook(offset: 50, limit: 50)
        XCTAssertEqual(list.path, "/plan/my-invitation/guestbook")
        XCTAssertEqual(list.query["offset"], "50")
        XCTAssertTrue(list.requiresAuth)
        let edit = try Endpoint.editMyGuestbook(wishId: "w 1", name: "하은", message: "축하")
        XCTAssertEqual(edit.method, .patch)
        XCTAssertEqual(edit.path, "/plan/my-invitation/guestbook/w%201")
        let body = try JSONSerialization.jsonObject(with: edit.body ?? Data()) as? [String: String]
        XCTAssertEqual(body, ["name": "하은", "message": "축하"])
        let delete = Endpoint.deleteMyGuestbook(wishId: "w1")
        XCTAssertEqual(delete.method, .delete)
        XCTAssertEqual(delete.path, "/plan/my-invitation/guestbook/w1")
    }
}
