import XCTest
import WPModels
import WPUtils
import WPNetworking
@testable import WPDomain

final class CoupleChatRulesTests: XCTestCase {
    private func room(permission: PlanPermission, couple: Bool, spouse: Bool = true) -> Plan {
        .init(roomId: 4, onwerName: "가", weddingDate: "2026-10-14", budget: 100, remainingBudget: 90, planCount: 1,
            chatRooms: [.init(id: 7, name: "대화", isCouple: couple)],
            members: [.init(planUserId: "ME", name: "나", permission: permission)] + (spouse ? [.init(planUserId: "other", name: " 상대 ", permission: .spouse)] : []))
    }
    func testOnlyCoupleChatSelectedAndLegacyReaderExcluded() {
        XCTAssertEqual(CoupleChatRules.pick([room(permission: .read, couple: true)], myId: "me"), .solo)
        XCTAssertEqual(CoupleChatRules.pick([room(permission: .owner, couple: true)], myId: " me "), .ready(chatRoomId: 7, planRoomId: 4, weddingDate: "2026-10-14", partnerName: "상대"))
        XCTAssertEqual(CoupleChatRules.pick([room(permission: .owner, couple: false)], myId: "me"), .unavailable)
        XCTAssertEqual(CoupleChatRules.pick([room(permission: .owner, couple: false, spouse: false)], myId: "me"), .solo)
    }
    func testDayDescriptionUsesKoreanCalendarDay() {
        let today = KstDate(year: 2026, month: 10, day: 13)!
        XCTAssertEqual(CoupleChatRules.describeWeddingDay("2026-10-14", today: today), "결혼식까지 1일 · 10월 14일")
        XCTAssertEqual(CoupleChatRules.describeWeddingDay("2026-10-13", today: today), "오늘 결혼식 · 10월 13일")
        XCTAssertEqual(CoupleChatRules.describeWeddingDay("2026-10-12", today: today), "결혼한 지 1일 · 10월 12일")
    }
    func testOldAndNewRoomAndInviteResponses() throws {
        XCTAssertFalse(try JSONDecoder().decode(ChatRoom.self, from: Data(#"{"id":7,"name":"대화"}"#.utf8)).isCouple)
        let chat = try JSONDecoder().decode(ChatRoom.self, from: Data(#"{"id":7,"isCouple":true,"memberCount":2}"#.utf8))
        XCTAssertTrue(chat.isCouple); XCTAssertEqual(chat.memberCount, 2)
        XCTAssertTrue(try JSONDecoder().decode(ShareCode.self, from: Data(#"{"shareCode":"abc"}"#.utf8)).canInvite)
        XCTAssertFalse(try JSONDecoder().decode(ShareCode.self, from: Data(#"{"shareCode":"abc","canInvite":false}"#.utf8)).canInvite)
    }
    func testScheduleShareAcknowledgementWireContract() {
        let frame = SocketIOPacket.event(namespace: "/chat", name: "message", argumentsJSON: #"{"room":7,"message":42,"messageType":"schedule"}"#, acknowledgement: 12)
        XCTAssertEqual(frame, #"42/chat,12["message",{"room":7,"message":42,"messageType":"schedule"}]"#)
        XCTAssertEqual(SocketIOPacket.decode(#"43/chat,12[{"ok":true}]"#), .acknowledgement(namespace: "/chat", id: 12, payload: #"[{"ok":true}]"#))
        XCTAssertEqual(SocketIOPacket.decode("43/chat,bad"), .unknown(raw: "43/chat,bad"))
    }
    func testSSEFramesMultilineKoreanAndCRLFWithoutDuplicateEvents() {
        var parser = SSEParser()
        let bytes = Data(": keepalive\r\ndata: 첫째\r\ndata: 둘째\r\n\r\nevent: update\ndata: {\"type\":\"CHAT_ROOMS_CHANGED\"}\n\ndata: unfinished".utf8)
        let events = bytes.compactMap { parser.consume($0) }
        XCTAssertEqual(events, ["첫째\n둘째", #"{"type":"CHAT_ROOMS_CHANGED"}"#])
    }
}
