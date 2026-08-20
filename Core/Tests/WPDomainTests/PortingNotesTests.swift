import XCTest
import WPModels
import WPUtils
import WPNetworking
@testable import WPDomain

/// `wedding-plant-android/docs/IOS_PORTING_NOTES.md` 가 경고한 함정들을 고정한다.
/// 전부 안드로이드에서 **실제로 시간을 잃은** 항목이라 회귀하면 같은 비용을 다시 낸다.
final class PortingNotesTests: XCTestCase {

    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: c)!
    }

    // MARK: - 1-8. createDate 는 UTC

    func test_UTC_시각을_KST_날짜로_바꾼다() {
        // UTC 13:02 = KST 22:02, 같은 날
        XCTAssertEqual(KstInstant.kstDate("2026-08-19T13:02:00.594Z")?.dateString, "2026-08-19")
        // UTC 15:30 = KST 다음날 00:30 — 그냥 앞 10글자를 자르면 하루 밀린다
        XCTAssertEqual(KstInstant.kstDate("2026-08-19T15:30:00Z")?.dateString, "2026-08-20")
        XCTAssertEqual(KstInstant.kstDate("2026-08-19T23:59:59Z")?.dateString, "2026-08-20")
    }

    func test_시각_표기는_KST_오전오후() {
        XCTAssertEqual(KstInstant.timeText("2026-08-19T13:02:00.594Z"), "오후 10:02")
        XCTAssertEqual(KstInstant.timeText("2026-08-19T00:30:00Z"), "오전 9:30")
        // KST 자정 → "오전 12:00"
        XCTAssertEqual(KstInstant.timeText("2026-08-19T15:00:00Z"), "오전 12:00")
        // KST 정오
        XCTAssertEqual(KstInstant.timeText("2026-08-19T03:00:00Z"), "오후 12:00")
    }

    func test_시각이_없거나_깨져도_빈문자열() {
        XCTAssertEqual(KstInstant.timeText(nil), "")
        XCTAssertEqual(KstInstant.timeText(""), "")
        XCTAssertEqual(KstInstant.timeText("이상한값"), "")
    }

    func test_날짜만_있는_문자열도_읽는다() {
        XCTAssertEqual(KstInstant.kstDate("2026-08-19")?.dateString, "2026-08-19")
    }

    // MARK: - 1-4. 날짜를 미정으로 되돌리려면 명시적 null

    func test_startDate가_nil이면_명시적_null로_직렬화된다() throws {
        let request = ScheduleWriteRequest(
            categoryName: "드레스", title: "가봉", startDate: nil
        )
        let json = String(data: try JSONEncoder().encode(request), encoding: .utf8)!
        XCTAssertTrue(
            json.contains("\"startDate\":null"),
            "키를 생략하면 백엔드가 '변경 없음' 으로 처리해 기존 날짜가 남는다: \(json)"
        )
    }

    func test_roomId가_nil이면_키가_빠진다() throws {
        // 수정(PATCH)에는 roomId 를 붙이면 안 된다.
        let request = ScheduleWriteRequest(
            categoryName: "드레스", title: "가봉", startDate: "2026-09-01", roomId: nil
        )
        let json = String(data: try JSONEncoder().encode(request), encoding: .utf8)!
        XCTAssertFalse(json.contains("roomId"), json)
    }

    func test_roomId가_있으면_직렬화된다() throws {
        let request = ScheduleWriteRequest(
            categoryName: "드레스", title: "가봉", startDate: "2026-09-01", roomId: 7
        )
        let json = String(data: try JSONEncoder().encode(request), encoding: .utf8)!
        XCTAssertTrue(json.contains("\"roomId\":7"), json)
    }

    // MARK: - 1-7. 채팅 메시지 id 는 숫자

    func test_채팅_메시지_id는_숫자다() throws {
        let json = #"{"id":70,"planUserId":"u1","text":"안녕하세요","createDate":"2026-08-19T13:02:00.594Z"}"#
        let message = try JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))
        XCTAssertEqual(message.id, 70)
        XCTAssertEqual(message.text, "안녕하세요")
    }

    // MARK: - 1-9. 멤버 목록은 list 또는 members

    func test_멤버_목록은_두_키를_모두_받는다() throws {
        let asList = #"{"list":[{"planUserId":"u1","name":"지수","permission":"OWNER"}]}"#
        let asMembers = #"{"members":[{"planUserId":"u1","name":"지수","permission":"OWNER"}]}"#
        XCTAssertEqual(try JSONDecoder().decode(MemberListPage.self, from: Data(asList.utf8)).list.count, 1)
        XCTAssertEqual(try JSONDecoder().decode(MemberListPage.self, from: Data(asMembers.utf8)).list.count, 1)
    }

    // MARK: - 3-1. 푸시 페이로드는 전부 문자열

    func test_푸시_페이로드의_chatRoomId는_문자열로_온다() {
        let payload = PushPayload(userInfo: ["chatRoomId": "1", "senderName": "신부", "body": "안녕하세요"])
        XCTAssertEqual(payload.chatRoomId, 1)
        XCTAssertEqual(payload.senderName, "신부")
        XCTAssertEqual(payload.body, "안녕하세요")
    }

    // MARK: - 2-6. 미정 항목은 정렬 방향과 무관하게 맨 아래

    func test_날짜없는_항목은_오름차순에서도_내림차순에서도_맨_아래() {
        let items = [
            ScheduleItem(id: 1, categoryName: "A", title: "미정", startDate: nil),
            ScheduleItem(id: 2, categoryName: "B", title: "빠름", startDate: "2026-08-01"),
            ScheduleItem(id: 3, categoryName: "C", title: "느림", startDate: "2026-12-01"),
        ]

        let asc = ScheduleSort.sorted(items, by: .startDate, descending: false).map(\.id)
        XCTAssertEqual(asc, [2, 3, 1])

        let desc = ScheduleSort.sorted(items, by: .startDate, descending: true).map(\.id)
        XCTAssertEqual(desc, [3, 2, 1])
    }

    func test_금액_정렬() {
        let items = [
            ScheduleItem(id: 1, categoryName: "A", title: "a", amount: 500),
            ScheduleItem(id: 2, categoryName: "B", title: "b", amount: nil),
            ScheduleItem(id: 3, categoryName: "C", title: "c", amount: 1200),
        ]
        XCTAssertEqual(ScheduleSort.sorted(items, by: .amount, descending: true).map(\.id), [3, 1, 2])
    }

    // MARK: - 카테고리 추천 (웹 matchesCategoryLabel)

    func test_한_글자_라벨은_추천하지_않는다() {
        XCTAssertFalse(PlanRules.matchesCategoryLabel("홀리데이 스냅", "홀"))
    }

    func test_두_글자_라벨은_토큰_경계에서만() {
        // "기타 소품" 안의 "기타" 는 경계에 있으므로 매칭
        XCTAssertTrue(PlanRules.matchesCategoryLabel("기타 소품", "기타"))
        // "기타리스트" 안의 "기타" 는 경계가 아니라 매칭 안 됨
        XCTAssertFalse(PlanRules.matchesCategoryLabel("기타리스트 섭외", "기타"))
    }

    func test_세_글자_이상은_부분_문자열() {
        XCTAssertTrue(PlanRules.matchesCategoryLabel("본식스냅작가", "본식스냅"))
    }

    func test_추천은_긴_라벨을_위로_올린다() {
        let result = PlanRules.suggestCategories(
            title: "본식 스튜디오 촬영",
            categories: ["스튜디오", "본식 스튜디오", "드레스"]
        )
        XCTAssertEqual(result.first, "본식 스튜디오")
    }

    // MARK: - 파스텔 팔레트는 8색이고 기존 6색과 섞이면 안 된다

    func test_파스텔_팔레트는_8색이다() {
        XCTAssertEqual(PlanRules.categoryPastelColors.count, 8)
        XCTAssertEqual(PlanRules.categoryColors.count, 6)
        for name in ["웨딩홀", "스튜디오", "드레스", "메이크업"] {
            XCTAssertTrue(PlanRules.categoryPastelColors.contains(PlanRules.categoryPastelHex(name)))
        }
    }
}

/// 정렬 선택지는 안드로이드와 **라벨까지 동일**해야 한다.
final class SortOptionTests: XCTestCase {

    func test_여섯_가지_선택지() {
        XCTAssertEqual(SortOption.allCases.count, 6)
    }

    func test_기본값은_시작일_최신순() {
        XCTAssertEqual(SortOption.default, .dateDesc)
        XCTAssertEqual(SortOption.default.buttonLabel, "시작")
        XCTAssertTrue(SortOption.default.descending)
    }

    func test_시트_라벨() {
        XCTAssertEqual(SortOption.priceAsc.sheetLabel, "낮은 가격순")
        XCTAssertEqual(SortOption.priceDesc.sheetLabel, "높은 가격순")
        XCTAssertEqual(SortOption.dateAsc.sheetLabel, "플랜 시작일 오래된순")
        XCTAssertEqual(SortOption.dateDesc.sheetLabel, "플랜 시작일 최신순")
        XCTAssertEqual(SortOption.nameAsc.sheetLabel, "제목 가나다순")
        XCTAssertEqual(SortOption.nameDesc.sheetLabel, "제목 가나다역순")
    }

    func test_버튼_라벨은_세_종류() {
        XCTAssertEqual(SortOption.priceAsc.buttonLabel, "가격")
        XCTAssertEqual(SortOption.dateAsc.buttonLabel, "시작")
        XCTAssertEqual(SortOption.nameAsc.buttonLabel, "제목")
    }

    func test_백엔드_파라미터() {
        XCTAssertEqual(SortOption.priceDesc.column.parameter, "amount")
        XCTAssertEqual(SortOption.dateDesc.column.parameter, "startDate")
        XCTAssertEqual(SortOption.nameAsc.column.parameter, "title")
    }
}

/// 카테고리 경로 분기. 게스트가 인증 없이 부를 수 있어야 한다.
final class CategoryEndpointTests: XCTestCase {

    func test_방이_있으면_방_경로() {
        let request = Endpoint.categories(roomId: 7, loggedIn: true)
        XCTAssertEqual(request.path, "/plan/category/room/7/list")
        XCTAssertTrue(request.requiresAuth)
    }

    func test_로그인했고_방이_없으면_user_경로() {
        let request = Endpoint.categories(roomId: nil, loggedIn: true)
        XCTAssertEqual(request.path, "/plan/category/user/list")
        XCTAssertTrue(request.requiresAuth)
    }

    func test_비로그인은_인증_없이_기본_경로() {
        // 이걸 틀리면 게스트에게 카테고리가 하나도 안 보이고, 카테고리가 필수라
        // 게스트는 플랜을 아예 만들 수 없다.
        let request = Endpoint.categories(roomId: nil, loggedIn: false)
        XCTAssertEqual(request.path, "/plan/category/list")
        XCTAssertFalse(request.requiresAuth)
    }

    func test_장소검색_쿼리() {
        let request = Endpoint.searchPlaces(query: "  강남 웨딩홀  ", size: 10)
        XCTAssertEqual(request.path, "/plan/place/search")
        XCTAssertEqual(request.query["query"], "강남 웨딩홀")
        XCTAssertEqual(request.query["size"], "10")
    }
}

/// 결제 유형 라벨은 웹 PAY_TYPE_LABELS 와 동일해야 한다.
final class PlanPayTypeTests: XCTestCase {

    func test_라벨() {
        XCTAssertEqual(PlanPayType.cash.label, "현금")
        XCTAssertEqual(PlanPayType.credit.label, "카드")
        XCTAssertEqual(PlanPayType.other.label, "기타")
    }

    func test_api_값에서_복원() {
        XCTAssertEqual(PlanPayType.from(api: "CREDIT"), .credit)
        XCTAssertNil(PlanPayType.from(api: nil))
        XCTAssertNil(PlanPayType.from(api: "UNKNOWN"))
    }
}
