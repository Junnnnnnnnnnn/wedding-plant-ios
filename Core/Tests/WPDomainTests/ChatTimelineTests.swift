import XCTest
import WPModels
import WPUtils
@testable import WPDomain

/// 채팅 목록 규칙. 중복·순서·날짜 구분선이 어긋나면 화면에서 바로 티가 난다.
final class ChatTimelineTests: XCTestCase {

    private let myId = "me"

    private func line(
        _ id: String,
        at createDate: String,
        sender: String = "other",
        unread: Int = 0
    ) -> ChatLine {
        ChatLine(
            id: id,
            senderId: sender,
            senderName: sender,
            text: "메시지 \(id)",
            createDate: createDate,
            isMine: sender == myId,
            unreadCount: unread
        )
    }

    private func decodePayload(_ json: String) throws -> SocketChatPayload {
        try JSONDecoder().decode(SocketChatPayload.self, from: Data(json.utf8))
    }

    // MARK: - 내 메시지 판별

    func test_보낸_사람이_나인지() {
        XCTAssertTrue(ChatTimeline.isMine(senderId: "me", myId: "me"))
        XCTAssertFalse(ChatTimeline.isMine(senderId: "other", myId: "me"))
        // 내 id 를 모르면 남의 메시지로 본다 (내 것으로 잘못 그리는 쪽이 더 이상하다)
        XCTAssertFalse(ChatTimeline.isMine(senderId: "me", myId: nil))
        XCTAssertFalse(ChatTimeline.isMine(senderId: "me", myId: "  "))
        // 공백은 다듬고 비교한다
        XCTAssertTrue(ChatTimeline.isMine(senderId: " me ", myId: "me"))
    }

    // MARK: - 기록 → 화면 순서

    func test_기록은_뒤집어서_오래된_것이_위로() {
        // 서버는 최신순으로 준다
        let page = [
            ChatHistoryItem(id: 3, planUserId: "a", createDate: "2026-08-20T03:00:00Z"),
            ChatHistoryItem(id: 2, planUserId: "a", createDate: "2026-08-20T02:00:00Z"),
            ChatHistoryItem(id: 1, planUserId: "a", createDate: "2026-08-20T01:00:00Z"),
        ]
        let lines = ChatTimeline.lines(from: page, myId: myId)
        XCTAssertEqual(lines.map(\.id), ["1", "2", "3"])
    }

    func test_한_페이지를_꽉_채우면_더_있다고_본다() {
        XCTAssertTrue(ChatTimeline.hasMore(receivedCount: 50))
        XCTAssertFalse(ChatTimeline.hasMore(receivedCount: 49))
        XCTAssertFalse(ChatTimeline.hasMore(receivedCount: 0))
    }

    // MARK: - 병합

    func test_같은_id는_한_번만_남는다() {
        let existing = [line("1", at: "2026-08-20T01:00:00Z")]
        let incoming = [
            line("1", at: "2026-08-20T01:00:00Z"),
            line("2", at: "2026-08-20T02:00:00Z"),
        ]
        XCTAssertEqual(ChatTimeline.merge(existing, incoming).map(\.id), ["1", "2"])
    }

    func test_병합_후_시간순으로_정렬된다() {
        // 재연결 직후 소켓 메시지가 REST 응답보다 먼저 들어와 있을 수 있다
        let existing = [line("9", at: "2026-08-20T05:00:00Z")]
        let incoming = [
            line("7", at: "2026-08-20T03:00:00Z"),
            line("8", at: "2026-08-20T04:00:00Z"),
        ]
        XCTAssertEqual(ChatTimeline.merge(existing, incoming).map(\.id), ["7", "8", "9"])
    }

    func test_같은_시각이면_숫자_id_순() {
        let lines = ChatTimeline.merge(
            [line("10", at: "2026-08-20T01:00:00Z")],
            [line("2", at: "2026-08-20T01:00:00Z")]
        )
        // 문자열 비교였다면 "10" 이 "2" 보다 앞에 온다. 숫자로 비교해야 한다.
        XCTAssertEqual(lines.map(\.id), ["2", "10"])
    }

    func test_임시_id는_같은_시각의_서버_id보다_뒤로() {
        let lines = ChatTimeline.merge(
            [line("sock-abc", at: "2026-08-20T01:00:00Z")],
            [line("5", at: "2026-08-20T01:00:00Z")]
        )
        XCTAssertEqual(lines.map(\.id), ["5", "sock-abc"])
    }

    func test_이전_페이지는_앞에_붙이고_중복은_버린다() {
        let existing = [line("3", at: "2026-08-20T03:00:00Z")]
        let older = [
            line("1", at: "2026-08-20T01:00:00Z"),
            line("3", at: "2026-08-20T03:00:00Z"),
        ]
        XCTAssertEqual(ChatTimeline.prepend(older, to: existing).map(\.id), ["1", "3"])
    }

    // MARK: - 날짜 구분선 · 이름

    func test_첫_줄에는_항상_날짜_구분선() {
        let lines = [line("1", at: "2026-08-20T01:00:00Z")]
        XCTAssertTrue(ChatTimeline.showsDateHeader(lines, at: 0))
    }

    func test_날짜가_바뀌면_구분선() {
        let lines = [
            line("1", at: "2026-08-20T01:00:00Z"),
            line("2", at: "2026-08-20T02:00:00Z"),
            line("3", at: "2026-08-21T01:00:00Z"),
        ]
        XCTAssertFalse(ChatTimeline.showsDateHeader(lines, at: 1))
        XCTAssertTrue(ChatTimeline.showsDateHeader(lines, at: 2))
    }

    func test_UTC_15시_이후는_KST로_다음_날이다() {
        // 앞 10글자를 그대로 쓰면 같은 날로 보여 구분선이 안 생긴다.
        let lines = [
            line("1", at: "2026-08-20T10:00:00Z"), // KST 8/20 19:00
            line("2", at: "2026-08-20T16:00:00Z"), // KST 8/21 01:00
        ]
        XCTAssertEqual(lines[0].dayKey, "2026-08-20")
        XCTAssertEqual(lines[1].dayKey, "2026-08-21")
        XCTAssertTrue(ChatTimeline.showsDateHeader(lines, at: 1))
    }

    func test_보낸_사람_이름은_묶음의_첫_줄에만() {
        let lines = [
            line("1", at: "2026-08-20T01:00:00Z", sender: "a"),
            line("2", at: "2026-08-20T02:00:00Z", sender: "a"),
            line("3", at: "2026-08-20T03:00:00Z", sender: "b"),
        ]
        XCTAssertTrue(ChatTimeline.showsSenderName(lines, at: 0))
        XCTAssertFalse(ChatTimeline.showsSenderName(lines, at: 1))
        XCTAssertTrue(ChatTimeline.showsSenderName(lines, at: 2))
    }

    func test_날짜가_바뀌면_같은_사람이어도_이름을_다시_보여준다() {
        let lines = [
            line("1", at: "2026-08-20T01:00:00Z", sender: "a"),
            line("2", at: "2026-08-21T01:00:00Z", sender: "a"),
        ]
        XCTAssertTrue(ChatTimeline.showsSenderName(lines, at: 1))
    }

    func test_내_메시지에는_이름을_붙이지_않는다() {
        let lines = [line("1", at: "2026-08-20T01:00:00Z", sender: myId)]
        XCTAssertFalse(ChatTimeline.showsSenderName(lines, at: 0))
    }

    func test_날짜_구분선_문구() {
        XCTAssertEqual(ChatTimeline.dateHeaderText("2026-08-20"), "2026년 8월 20일")
        // 한 자리 월·일은 0을 떼고 보여준다
        XCTAssertEqual(ChatTimeline.dateHeaderText("2026-01-05"), "2026년 1월 5일")
    }

    // MARK: - 전원 접속 시 읽음 처리

    func test_전원_접속이면_안읽음을_모두_지운다() {
        let lines = [line("1", at: "2026-08-20T01:00:00Z", unread: 2)]
        let cleared = ChatTimeline.clearUnreadIfEveryoneJoined(
            lines, connectedCount: 2, memberCount: 2
        )
        XCTAssertEqual(cleared.first?.unreadCount, 0)
    }

    func test_한_명이라도_빠지면_그대로_둔다() {
        let lines = [line("1", at: "2026-08-20T01:00:00Z", unread: 2)]
        XCTAssertEqual(
            ChatTimeline.clearUnreadIfEveryoneJoined(lines, connectedCount: 1, memberCount: 2)
                .first?.unreadCount,
            2
        )
        // 멤버 수를 모르면(0) 판단하지 않는다
        XCTAssertEqual(
            ChatTimeline.clearUnreadIfEveryoneJoined(lines, connectedCount: 5, memberCount: 0)
                .first?.unreadCount,
            2
        )
    }

    // MARK: - 소켓 페이로드

    func test_평평한_페이로드() throws {
        let payload = try decodePayload("""
        {"id":7,"planUserId":"me","planUserName":"지수","messageType":"text",
         "text":"안녕","createDate":"2026-08-20T01:00:00Z","unreadCount":1}
        """)
        let line = ChatTimeline.line(from: payload, myId: myId, fallbackId: "tmp")
        XCTAssertEqual(line.id, "7")
        XCTAssertEqual(line.senderName, "지수")
        XCTAssertEqual(line.text, "안녕")
        XCTAssertTrue(line.isMine)
        XCTAssertEqual(line.unreadCount, 1)
    }

    func test_중첩된_페이로드도_읽는다() throws {
        // 이쪽만 지원하지 않으면 어떤 서버 버전에서 말풍선이 비어 보인다.
        let payload = try decodePayload("""
        {"senderId":"other","senderName":"현우",
         "message":{"messageType":"text","text":"중첩"}}
        """)
        let line = ChatTimeline.line(from: payload, myId: myId, fallbackId: "tmp")
        XCTAssertEqual(line.senderId, "other")
        XCTAssertEqual(line.senderName, "현우")
        XCTAssertEqual(line.messageType, "text")
        XCTAssertEqual(line.text, "중첩")
        XCTAssertFalse(line.isMine)
    }

    func test_id가_문자열로_와도_받는다() throws {
        let payload = try decodePayload(#"{"id":"12","text":"x"}"#)
        XCTAssertEqual(ChatTimeline.line(from: payload, myId: myId, fallbackId: "tmp").id, "12")
    }

    func test_id가_없으면_임시_id를_쓴다() throws {
        let payload = try decodePayload(#"{"text":"x"}"#)
        XCTAssertEqual(
            ChatTimeline.line(from: payload, myId: myId, fallbackId: "sock-1").id,
            "sock-1"
        )
    }

    func test_보낸_사람_이름이_없으면_알_수_없음() throws {
        let payload = try decodePayload(#"{"text":"x"}"#)
        XCTAssertEqual(
            ChatTimeline.line(from: payload, myId: myId, fallbackId: "tmp").senderName,
            "알 수 없음"
        )
    }

    func test_시각이_없으면_지금으로_본다() throws {
        let payload = try decodePayload(#"{"text":"x"}"#)
        let now = Date(timeIntervalSince1970: 1_787_000_000)
        let line = ChatTimeline.line(from: payload, myId: myId, fallbackId: "tmp", now: now)
        XCTAssertFalse(line.createDate.isEmpty)
        XCTAssertNotNil(KstInstant.parse(line.createDate))
    }

    func test_일정_카드_페이로드() throws {
        let payload = try decodePayload("""
        {"id":9,"planUserId":"other","messageType":"schedule",
         "schedule":{"id":3,"categoryName":"드레스","title":"1차 피팅",
                     "amount":500,"startDate":"2026-09-01","status":"NORMAL","location":"강남"}}
        """)
        let line = ChatTimeline.line(from: payload, myId: myId, fallbackId: "tmp")
        XCTAssertEqual(line.messageType, "schedule")
        XCTAssertEqual(line.schedule?.title, "1차 피팅")
        XCTAssertEqual(line.schedule?.amount, 500)
        XCTAssertEqual(line.schedule?.location, "강남")
    }

    func test_문자열_null은_비어있는_것으로_본다() throws {
        // 서버가 "null" 문자열을 보내는 경우가 있다
        let payload = try decodePayload(#"{"id":"null","createDate":"null","text":"x"}"#)
        let line = ChatTimeline.line(from: payload, myId: myId, fallbackId: "sock-2")
        XCTAssertEqual(line.id, "sock-2")
        XCTAssertNotEqual(line.createDate, "null")
    }
}
