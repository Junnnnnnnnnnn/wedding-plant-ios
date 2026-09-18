import XCTest
@testable import WPDomain
@testable import WPModels

/// 자랑하기 상세의 묶음·소계.
///
/// **왼쪽 범례 색과 오른쪽 묶음 머리 색이 같아야 한다.** "이 1,240만원이 이 두
/// 장이다" 가 눈으로 붙는 것이 이 화면의 전부다.
final class BragRulesTests: XCTestCase {

    private func item(
        _ id: Int,
        _ category: String,
        _ amount: Int?,
        location: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil
    ) -> BragPlanItem {
        BragPlanItem(
            id: id, categoryName: category, title: "플랜 \(id)",
            amount: amount, location: location, lat: lat, lng: lng
        )
    }

    private let chart = [
        BragChartItem(categoryName: "예식장", usedAmount: 1200),
        BragChartItem(categoryName: "스튜디오", usedAmount: 450),
        BragChartItem(categoryName: "드레스", usedAmount: 300),
        BragChartItem(categoryName: "메이크업", usedAmount: 180),
        BragChartItem(categoryName: "청첩장", usedAmount: 40),
    ]

    // MARK: - 묶음

    func test_차트_순서대로_묶는다() {
        let groups = BragRules.groups(
            items: [item(1, "스튜디오", 450), item(2, "예식장", 1200)],
            chart: chart
        )
        XCTAssertEqual(groups.map(\.categoryName), ["예식장", "스튜디오"])
    }

    func test_소계는_지출과_예정을_함께_센다() {
        // 완료 185 + 예정 35 = 220
        let groups = BragRules.groups(
            items: [item(1, "예식장", 185), item(2, "예식장", 35)],
            chart: chart
        )
        XCTAssertEqual(groups.first?.subtotal, 220)
    }

    func test_다섯_번째부터는_색이_없다() {
        // `i % 4` 로 돌리면 다섯 번째가 첫 번째와 같은 분홍이 된다 —
        // 실제로 "청첩장" 이 "예식장" 과 같은 색으로 나왔다.
        let items = chart.enumerated().map { i, c in item(i, c.categoryName, 100) }
        let groups = BragRules.groups(items: items, chart: chart)
        XCTAssertEqual(groups.count, 5)
        XCTAssertEqual(groups.prefix(4).compactMap(\.colorIndex), [0, 1, 2, 3])
        XCTAssertNil(groups[4].colorIndex, "다섯 번째는 무채색이다")
    }

    func test_차트에_없는_카테고리도_빠지지_않는다() {
        // 그냥 빼면 막대가 실제 지출보다 짧아진다.
        let groups = BragRules.groups(
            items: [item(1, "예식장", 100), item(2, "혼수", 50)],
            chart: chart
        )
        XCTAssertEqual(groups.map(\.categoryName), ["예식장", "혼수"])
        XCTAssertEqual(groups.map(\.subtotal), [100, 50])
    }

    func test_카테고리가_비면_그_외로_묶는다() {
        let groups = BragRules.groups(items: [item(1, "", 70)], chart: [])
        XCTAssertEqual(groups.first?.categoryName, "그 외")
    }

    // MARK: - 몫

    func test_둘_이상일_때만_몫을_말한다() {
        let groups = BragRules.groups(
            items: [item(1, "예식장", 180), item(2, "예식장", 20)],
            chart: chart
        )
        let group = try! XCTUnwrap(groups.first)
        XCTAssertEqual(BragRules.sharePercent(item: group.items[0], in: group), 90)
    }

    func test_하나뿐이면_몫을_말하지_않는다() {
        // 늘 100% 라 "180만 원 가운데 100%" 처럼 같은 말을 두 번 하는 문장이 된다.
        let groups = BragRules.groups(items: [item(1, "예식장", 180)], chart: chart)
        let group = try! XCTUnwrap(groups.first)
        XCTAssertNil(BragRules.sharePercent(item: group.items[0], in: group))
    }

    func test_소계가_0이면_몫을_말하지_않는다() {
        let groups = BragRules.groups(
            items: [item(1, "예식장", 0), item(2, "예식장", 0)],
            chart: chart
        )
        let group = try! XCTUnwrap(groups.first)
        XCTAssertNil(BragRules.sharePercent(item: group.items[0], in: group))
    }

    // MARK: - 지도

    func test_좌표가_있으면_지도를_낸다() {
        XCTAssertNil(
            BragRules.mapAbsence(for: item(1, "예식장", 100, location: "SG웨딩홀", lat: 37.5, lng: 127.0))
        )
    }

    func test_장소가_없는_것과_좌표가_없는_것을_갈라_적는다() {
        // 줄이나 상자가 사라지면 "안 적었나" 와 "화면이 안 그렸나" 를 구별할 수 없다.
        XCTAssertEqual(BragRules.mapAbsence(for: item(1, "예물", 100)), .noPlace)
        XCTAssertEqual(
            BragRules.mapAbsence(for: item(2, "신혼여행", 100, location: "푸꾸옥 호텔")),
            .noCoordinates
        )
        XCTAssertEqual(
            BragRules.mapAbsence(for: item(3, "신혼여행", 100, location: "푸꾸옥 호텔", lat: 0, lng: 0)),
            .noCoordinates,
            "좌표 0,0 은 없음이다 — 해외 장소가 그렇게 저장된다"
        )
    }

    func test_지도를_못_내는_이유를_문장으로_낸다() {
        XCTAssertEqual(BragRules.MapAbsence.noPlace.message, "장소를 등록하지 않은 일정이에요")
        XCTAssertEqual(BragRules.MapAbsence.noCoordinates.message, "지도에 표시할 수 없는 장소예요")
    }

    // MARK: - 좋아요

    func test_좋아요는_낙관적으로_뒤집힌다() {
        let on = BragRules.applyLike(liked: false, likeCount: 3)
        XCTAssertTrue(on.liked)
        XCTAssertEqual(on.likeCount, 4)

        let off = BragRules.applyLike(liked: true, likeCount: 4)
        XCTAssertFalse(off.liked)
        XCTAssertEqual(off.likeCount, 3)
    }

    func test_좋아요_수가_0_아래로_내려가지_않는다() {
        XCTAssertEqual(BragRules.applyLike(liked: true, likeCount: 0).likeCount, 0)
    }

    // MARK: - 공개 범위

    func test_상세_항목에_시각과_메모가_없다() throws {
        // 공개 범위 밖이라 서버가 아예 안 내려 준다.
        // **이 목록을 늘리려면 안내 모달의 문구를 먼저 고친다.**
        let decoded = try JSONDecoder().decode(
            BragPlanItem.self,
            from: Data(#"{"id":1,"title":"본식","startTime":"11:00","memo":"비밀"}"#.utf8)
        )
        let encoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        XCTAssertFalse(encoded.contains("startTime"))
        XCTAssertFalse(encoded.contains("memo"))
    }

    func test_결제_축은_일정_완료와_다르다() throws {
        // 상세의 소계도 결제 기준을 쓸 수 있어야 한다.
        let paidAhead = BragPlanItem(id: 1, status: "PLANNED", isPaid: true)
        XCTAssertTrue(paidAhead.isPaid)
        XCTAssertFalse(paidAhead.isScheduleCompleted)

        let legacy = BragPlanItem(id: 2, status: "COMPLETED", isPaid: nil)
        XCTAssertTrue(legacy.isPaid, "값이 없던 시절에는 완료가 곧 결제였다")
    }
}
