import XCTest
@testable import WPDomain
@testable import WPModels
@testable import WPUtils

/// 견적 후기의 문구·계산 규칙.
///
/// **익명·프라이버시는 백엔드와 짝이라 타협하지 않는다** — 응답에 `planUserId` 가
/// 없고, `"안 돼요" 수`는 내려오지 않는다. 여기서는 그 전제 위의 규칙만 고정한다.
final class FeedRulesTests: XCTestCase {

    private func post(
        role: String = "UNKNOWN",
        dday: Int? = nil,
        amount: Int? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        title: String = "SG웨딩홀"
    ) -> FeedPost {
        FeedPost(
            id: 1,
            title: title,
            amount: amount,
            lat: lat,
            lng: lng,
            authorDDay: dday,
            authorRole: role
        )
    }

    // MARK: - 작성자

    func test_남은_일수와_역할로_문장을_만든다() {
        XCTAssertEqual(FeedRules.describeAuthor(post(role: "BRIDE", dday: 131)), "D-131 신부")
        XCTAssertEqual(FeedRules.describeAuthor(post(role: "GROOM", dday: 7)), "D-7 신랑")
    }

    func test_당일과_지난_뒤() {
        XCTAssertEqual(FeedRules.describeAuthor(post(role: "BRIDE", dday: 0)), "D-Day 신부")
        XCTAssertEqual(FeedRules.describeAuthor(post(role: "GROOM", dday: -3)), "결혼식 3일 뒤 신랑")
    }

    func test_역할을_모르면_예비부부다() {
        XCTAssertEqual(FeedRules.describeAuthor(post(dday: 10)), "D-10 예비부부")
        XCTAssertEqual(FeedRules.describeAuthor(post(role: "SOMETHING", dday: 10)), "D-10 예비부부")
    }

    func test_날짜가_없으면_역할만_말한다() {
        XCTAssertEqual(FeedRules.describeAuthor(post(role: "BRIDE", dday: nil)), "신부")
    }

    // MARK: - 올린 때

    private let now = ISO8601DateFormatter().date(from: "2026-09-18T12:00:00Z")!

    func test_상대_시각() {
        func when(_ iso: String) -> String { FeedRules.describeWhen(iso, now: now) }
        XCTAssertEqual(when("2026-09-18T09:00:00Z"), "오늘")
        XCTAssertEqual(when("2026-09-17T09:00:00Z"), "어제")
        XCTAssertEqual(when("2026-09-15T09:00:00Z"), "3일 전")
        XCTAssertEqual(when("2026-09-08T09:00:00Z"), "1주 전")
    }

    func test_한_달이_넘으면_날짜로_적는다() {
        // KST 기준 날짜로 적는다.
        XCTAssertEqual(FeedRules.describeWhen("2026-07-04T09:00:00Z", now: now), "2026. 7. 4.")
    }

    func test_값이_없거나_형식이_아니면_빈_문자열이다() {
        XCTAssertEqual(FeedRules.describeWhen(nil, now: now), "")
        XCTAssertEqual(FeedRules.describeWhen("", now: now), "")
        XCTAssertEqual(FeedRules.describeWhen("어제", now: now), "")
    }

    // MARK: - 지도

    func test_좌표가_있어야_카카오맵_링크가_열린다() {
        XCTAssertNotNil(FeedRules.kakaoMapLink(post(lat: 37.5, lng: 127.0)))
        XCTAssertNil(FeedRules.kakaoMapLink(post(lat: nil, lng: nil)))
    }

    func test_좌표_0_0_은_없음이다() {
        // 카카오 검색으로 고르지 않으면 0 이 들어간다 — **해외 장소가 그렇게 저장된다.**
        // null 만 걸러 내면 기니 만 앞바다에 마커가 찍힌 빈 지도가 그려진다.
        XCTAssertNil(FeedRules.kakaoMapLink(post(lat: 0, lng: 0)))
        XCTAssertFalse(post(lat: 0, lng: 0).hasCoordinates)
        XCTAssertTrue(post(lat: 0, lng: 127.0).hasCoordinates, "한쪽만 0 인 좌표는 있는 것이다")
    }

    // MARK: - 시세 자

    private let stats = FeedCategoryStats(
        categoryName: "예식장", sampleCount: 42, median: 1000, p25: 800, p75: 1400
    )

    func test_p25_p75_가_자의_끝이_아니다() {
        // spread 600 → 자는 200 ~ 2000.
        // 가운데 절반만 그리면 그 밖의 후기가 자 밖으로 나간다.
        XCTAssertEqual(FeedRules.scalePercent(800, stats: stats), 33.33, accuracy: 0.1)
        XCTAssertEqual(FeedRules.scalePercent(1400, stats: stats), 66.67, accuracy: 0.1)
        XCTAssertEqual(FeedRules.scalePercent(1100, stats: stats), 50, accuracy: 0.1)
    }

    func test_자_밖으로_나가도_6에서_94_안에_머문다() {
        // 라벨이 잘리지 않게 눌러 둔다.
        XCTAssertEqual(FeedRules.scalePercent(0, stats: stats), 6, accuracy: 0.001)
        XCTAssertEqual(FeedRules.scalePercent(99_999, stats: stats), 94, accuracy: 0.001)
    }

    func test_사분위가_같아도_0으로_나누지_않는다() {
        let flat = FeedCategoryStats(sampleCount: 9, median: 500, p25: 500, p75: 500)
        let pct = FeedRules.scalePercent(500, stats: flat)
        XCTAssertTrue(pct >= 6 && pct <= 94)
    }

    // MARK: - 투표

    func test_처음_누르면_도움돼요가_하나_는다() {
        let next = FeedRules.applyVote(current: nil, helpfulCount: 3, tapped: .helpful)
        XCTAssertEqual(next.myVote, "HELPFUL")
        XCTAssertEqual(next.helpfulCount, 4)
        XCTAssertFalse(next.isCancel)
    }

    func test_같은_값을_다시_누르면_취소다() {
        let next = FeedRules.applyVote(current: "HELPFUL", helpfulCount: 4, tapped: .helpful)
        XCTAssertNil(next.myVote)
        XCTAssertEqual(next.helpfulCount, 3)
        XCTAssertTrue(next.isCancel, "DELETE 를 보내야 한다")
    }

    func test_마음을_바꾸면_행이_늘지_않고_값이_뒤집힌다() {
        let next = FeedRules.applyVote(current: "HELPFUL", helpfulCount: 4, tapped: .notHelpful)
        XCTAssertEqual(next.myVote, "NOT_HELPFUL")
        XCTAssertEqual(next.helpfulCount, 3, "도움돼요에서 빠진다")
        XCTAssertFalse(next.isCancel)

        let back = FeedRules.applyVote(current: "NOT_HELPFUL", helpfulCount: 3, tapped: .helpful)
        XCTAssertEqual(back.myVote, "HELPFUL")
        XCTAssertEqual(back.helpfulCount, 4)
    }

    func test_안돼요만_눌렀다_취소해도_도움돼요는_그대로다() {
        let on = FeedRules.applyVote(current: nil, helpfulCount: 5, tapped: .notHelpful)
        XCTAssertEqual(on.helpfulCount, 5, "안 돼요는 이 숫자를 건드리지 않는다")
        let off = FeedRules.applyVote(current: "NOT_HELPFUL", helpfulCount: 5, tapped: .notHelpful)
        XCTAssertEqual(off.helpfulCount, 5)
        XCTAssertTrue(off.isCancel)
    }

    func test_수가_0_아래로_내려가지_않는다() {
        let next = FeedRules.applyVote(current: "HELPFUL", helpfulCount: 0, tapped: .helpful)
        XCTAssertEqual(next.helpfulCount, 0)
    }

    // MARK: - 비공개 금액

    func test_비공개_금액은_0이_아니라_없음이다() throws {
        // `?? 0` 으로 채우면 "0원" 으로 그려진다.
        let hidden = try JSONDecoder().decode(
            FeedPost.self,
            from: Data(#"{ "id": 1, "title": "SG웨딩홀", "isAmountPublic": false }"#.utf8)
        )
        XCTAssertNil(hidden.amount)
        XCTAssertFalse(hidden.isAmountPublic)

        let shown = try JSONDecoder().decode(
            FeedPost.self,
            from: Data(#"{ "id": 2, "title": "A", "amount": 1200, "isAmountPublic": true }"#.utf8)
        )
        XCTAssertEqual(shown.amount, 1200)
    }

    func test_안돼요_수는_응답에_없다() throws {
        // 회귀 방지: 정직하게 올린 후기에 "안 돼요 12" 가 박히면 다음 사람이 안 올린다.
        // 서버가 보내더라도 모델이 받지 않는다.
        let decoded = try JSONDecoder().decode(
            FeedPost.self,
            from: Data(#"{ "id": 1, "helpfulCount": 7, "notHelpfulCount": 12 }"#.utf8)
        )
        XCTAssertEqual(decoded.helpfulCount, 7)
        let encoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        XCTAssertFalse(encoded.contains("notHelpful"))
    }
}
