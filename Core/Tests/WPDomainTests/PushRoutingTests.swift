import XCTest
import WPModels
@testable import WPDomain

/// 푸시 표시 규칙. 여기가 틀리면 같은 메시지로 알림이 두 번 뜨거나,
/// 보고 있는 대화에 대고 배너가 뜬다.
final class PushRoutingTests: XCTestCase {

    private func payload(roomId: String? = "1", sender: String = "현우", body: String = "안녕하세요")
        -> PushPayload {
        var userInfo: [AnyHashable: Any] = ["senderName": sender, "body": body]
        if let roomId { userInfo["chatRoomId"] = roomId }
        return PushPayload(userInfo: userInfo)
    }

    // MARK: - 페이로드

    func test_값은_전부_문자열로_온다() {
        // 백엔드는 chatRoomId 도 1 이 아니라 "1" 로 보낸다.
        XCTAssertEqual(payload(roomId: "1").chatRoomId, 1)
        XCTAssertEqual(payload().senderName, "현우")
        XCTAssertEqual(payload().body, "안녕하세요")
    }

    func test_숫자로_와도_받는다() {
        let parsed = PushPayload(userInfo: ["chatRoomId": 7])
        XCTAssertEqual(parsed.chatRoomId, 7)
    }

    func test_방_번호가_없으면_nil() {
        XCTAssertNil(payload(roomId: nil).chatRoomId)
        XCTAssertNil(PushPayload(userInfo: ["chatRoomId": "숫자아님"]).chatRoomId)
    }

    // MARK: - 무엇을 띄울지

    func test_백그라운드면_시스템_알림() {
        XCTAssertEqual(
            PushRouting.display(for: payload(), appActive: false, currentChatRoomId: nil),
            .system
        )
        // 백그라운드에서는 어느 방을 보고 있든 시스템이 배너를 띄운다 (앱이 개입할 수 없다)
        XCTAssertEqual(
            PushRouting.display(for: payload(), appActive: false, currentChatRoomId: 1),
            .system
        )
    }

    func test_앱이_켜져_있으면_배너_대신_토스트() {
        XCTAssertEqual(
            PushRouting.display(for: payload(), appActive: true, currentChatRoomId: nil),
            .inAppOnly
        )
        // 다른 방을 보고 있어도 토스트는 띄운다
        XCTAssertEqual(
            PushRouting.display(for: payload(roomId: "2"), appActive: true, currentChatRoomId: 1),
            .inAppOnly
        )
    }

    func test_보고_있는_방이면_아무것도_안_띄운다() {
        XCTAssertEqual(
            PushRouting.display(for: payload(roomId: "1"), appActive: true, currentChatRoomId: 1),
            .suppress
        )
    }

    func test_방_번호를_모르면_보고_있는_방인지_판단하지_않는다() {
        XCTAssertEqual(
            PushRouting.display(for: payload(roomId: nil), appActive: true, currentChatRoomId: 1),
            .inAppOnly
        )
    }

    // MARK: - 눌렀을 때

    func test_알림을_누르면_그_채팅방으로() {
        XCTAssertEqual(PushRouting.destination(for: payload(roomId: "10")), .chatRoom(id: 10))
    }

    func test_방_번호가_없으면_앱만_연다() {
        XCTAssertEqual(PushRouting.destination(for: payload(roomId: nil)), .none)
    }

    // MARK: - 토스트 문구

    func test_토스트_문구() {
        XCTAssertEqual(PushRouting.toastText(for: payload()), "현우: 안녕하세요")
    }

    func test_보낸_사람이_없으면_본문만() {
        XCTAssertEqual(PushRouting.toastText(for: payload(sender: "")), "안녕하세요")
    }

    func test_본문이_없으면_보낸_사람만() {
        XCTAssertEqual(PushRouting.toastText(for: payload(body: "")), "현우")
    }

    // MARK: - 기기 토큰

    func test_APNs_토큰을_16진_문자열로() {
        let data = Data([0x00, 0x0f, 0xa1, 0xff])
        XCTAssertEqual(PushRouting.hexToken(data), "000fa1ff")
    }

    func test_빈_토큰() {
        XCTAssertEqual(PushRouting.hexToken(Data()), "")
    }
}
