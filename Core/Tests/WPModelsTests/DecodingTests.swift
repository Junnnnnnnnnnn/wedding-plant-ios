import XCTest
@testable import WPModels

final class DecodingTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - APIEnvelope

    func test_envelope_성공응답() throws {
        let envelope = try decode(APIEnvelope<PlanUser>.self, """
        { "result": true, "data": { "name": "지수", "weddingDate": "2026-10-10", "budget": 5000 } }
        """)
        XCTAssertTrue(envelope.result)
        XCTAssertEqual(envelope.data?.name, "지수")
        XCTAssertEqual(envelope.data?.budget, 5000)
    }

    func test_envelope_result가_없으면_false로_본다() throws {
        let envelope = try decode(APIEnvelope<PlanUser>.self, #"{ "error": "BAD_REQUEST" }"#)
        XCTAssertFalse(envelope.result)
        XCTAssertNil(envelope.data)
        XCTAssertEqual(envelope.error, "BAD_REQUEST")
    }

    func test_envelope_data가_null이어도_디코딩된다() throws {
        let envelope = try decode(APIEnvelope<PlanUser>.self, #"{ "result": true, "data": null }"#)
        XCTAssertTrue(envelope.result)
        XCTAssertNil(envelope.data)
    }

    // MARK: - LooseInt

    func test_budget이_문자열로_와도_숫자로_읽는다() throws {
        // 웹이 `budget?: number | string | null` 로 선언한 이유를 그대로 방어한다.
        let user = try decode(PlanUser.self, #"{ "budget": "5000" }"#)
        XCTAssertEqual(user.budget, 5000)
    }

    func test_budget이_실수로_와도_읽는다() throws {
        XCTAssertEqual(try decode(PlanUser.self, #"{ "budget": 5000.0 }"#).budget, 5000)
    }

    func test_budget이_null이거나_없으면_nil이다() throws {
        XCTAssertNil(try decode(PlanUser.self, #"{ "budget": null }"#).budget)
        XCTAssertNil(try decode(PlanUser.self, #"{ "name": "지수" }"#).budget)
    }

    func test_budget이_해석불가_문자열이면_nil이고_전체_디코딩은_살아남는다() throws {
        let user = try decode(PlanUser.self, #"{ "name": "지수", "budget": "미정" }"#)
        XCTAssertNil(user.budget)
        XCTAssertEqual(user.name, "지수")
    }

    // MARK: - Plan

    func test_Plan은_백엔드_오타필드_onwerName을_읽는다() throws {
        let plan = try decode(Plan.self, """
        {
          "roomId": 7,
          "onwerName": "신랑측",
          "weddingDate": "2026-10-10",
          "budget": 5000,
          "remainingBudget": 1200,
          "planCount": 14,
          "chatRooms": [{ "id": 3, "name": "본식" }],
          "members": [{ "planUserId": "u1", "name": "지수", "image": null, "permission": "OWNER" }]
        }
        """)
        XCTAssertEqual(plan.onwerName, "신랑측")
        XCTAssertEqual(plan.ownerName, "신랑측")
        XCTAssertNil(plan.chatRooms.first?.memberList)
        XCTAssertEqual(plan.members.first?.permission, .owner)
        XCTAssertTrue(plan.members.first!.permission.canEdit)
    }

    func test_Plan은_선택필드가_빠져도_기본값으로_채운다() throws {
        let plan = try decode(Plan.self, #"{ "roomId": 1 }"#)
        XCTAssertEqual(plan.roomId, 1)
        XCTAssertEqual(plan.budget, 0)
        XCTAssertTrue(plan.members.isEmpty)
        XCTAssertTrue(plan.chatRooms.isEmpty)
    }

    func test_알_수_없는_permission도_디코딩된다() throws {
        let member = try decode(Member.self, #"{ "planUserId": "u1", "name": "하객", "permission": "VIEWER" }"#)
        XCTAssertEqual(member.permission.rawValue, "VIEWER")
        XCTAssertFalse(member.permission.canEdit)
    }

    func test_RoomList는_total이_없으면_list_길이로_보정한다() throws {
        let list = try decode(RoomList.self, #"{ "list": [{ "roomId": 1 }, { "roomId": 2 }] }"#)
        XCTAssertEqual(list.total, 2)
    }

    // MARK: - ScheduleItem

    func test_ScheduleItem_리스트응답_최소필드() throws {
        let item = try decode(ScheduleItem.self, """
        { "id": 42, "categoryName": "스튜디오", "title": "본식 촬영", "amount": null,
          "startDate": "2026-09-01", "status": "COMPLETED" }
        """)
        XCTAssertEqual(item.id, 42)
        XCTAssertNil(item.amount)
        XCTAssertEqual(item.status, .completed)
        XCTAssertTrue(item.status!.isCompleted)
        XCTAssertFalse(item.isGuest)
    }

    func test_음수_id는_게스트_로컬_항목이다() {
        let item = ScheduleItem(id: -1_723_000, categoryName: "웨딩홀", title: "상담")
        XCTAssertTrue(item.isGuest)
    }

    // MARK: - ScheduleWriteRequest

    func test_게스트항목_변환_시_빈_시작일은_대체된다() {
        let item = ScheduleItem(id: -1, categoryName: "드레스", title: "가봉", startDate: "   ")
        let request = ScheduleWriteRequest(guestItem: item, fallbackStartDate: "2026-08-14")
        XCTAssertEqual(request.startDate, "2026-08-14")
        XCTAssertEqual(request.payType, "OTHER")
        XCTAssertEqual(request.amount, 0)
    }

    func test_게스트항목_변환_시_빈_추가카테고리는_전송하지_않는다() {
        let empty = ScheduleItem(id: -1, categoryName: "드레스", title: "가봉", addCategoryNameList: [])
        XCTAssertNil(ScheduleWriteRequest(guestItem: empty, fallbackStartDate: "2026-08-14").addCategoryNameList)

        let filled = ScheduleItem(id: -2, categoryName: "드레스", title: "가봉", addCategoryNameList: ["헤어", "메이크업"])
        XCTAssertEqual(
            ScheduleWriteRequest(guestItem: filled, fallbackStartDate: "2026-08-14").addCategoryNameList,
            ["헤어", "메이크업"]
        )
    }
}

/// 일정 상세 응답. 웹 PAY_TYPE_LABELS 와 지도 링크 판정을 고정한다.
final class ScheduleDetailTests: XCTestCase {

    private func decode(_ json: String) throws -> ScheduleDetail {
        try JSONDecoder().decode(ScheduleDetail.self, from: Data(json.utf8))
    }

    func test_결제방식_라벨() throws {
        XCTAssertEqual(try decode(#"{"id":1,"payType":"CASH"}"#).payTypeLabel, "현금")
        XCTAssertEqual(try decode(#"{"id":1,"payType":"CREDIT"}"#).payTypeLabel, "카드")
        XCTAssertEqual(try decode(#"{"id":1,"payType":"OTHER"}"#).payTypeLabel, "기타")
        XCTAssertEqual(try decode(#"{"id":1}"#).payTypeLabel, "미정")
        XCTAssertEqual(try decode(#"{"id":1,"payType":""}"#).payTypeLabel, "미정")
    }

    func test_좌표가_0_0이면_지도를_띄우지_않는다() throws {
        let zero = try decode(#"{"id":1,"location":"서울","locationLat":0,"locationLng":0}"#)
        XCTAssertFalse(zero.hasCoordinates)
        XCTAssertNil(zero.kakaoMapURL)

        let real = try decode(#"{"id":1,"location":"서울","locationLat":37.5,"locationLng":127.0}"#)
        XCTAssertTrue(real.hasCoordinates)
        XCTAssertNotNil(real.kakaoMapURL)
    }

    func test_장소명이_없으면_지도_링크가_없다() throws {
        let noName = try decode(#"{"id":1,"locationLat":37.5,"locationLng":127.0}"#)
        XCTAssertTrue(noName.hasCoordinates)
        XCTAssertNil(noName.kakaoMapURL)
    }

    func test_금액이_소수로_와도_디코딩된다() throws {
        XCTAssertEqual(try decode(#"{"id":1,"amount":1200.0}"#).amount, 1200)
        XCTAssertNil(try decode(#"{"id":1,"amount":null}"#).amount)
    }

    func test_완료_판정() throws {
        XCTAssertTrue(try decode(#"{"id":1,"status":"COMPLETED"}"#).isCompleted)
        XCTAssertFalse(try decode(#"{"id":1,"status":"NORMAL"}"#).isCompleted)
    }
}
