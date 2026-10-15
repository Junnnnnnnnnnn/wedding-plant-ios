import XCTest
import WPModels
@testable import WPDomain

/// 안드로이드 `AdRulesTest` 와 같은 표. 한쪽만 바뀌면 두 앱의 광고 자리가 갈린다.
final class AdRulesTests: XCTestCase {
    private let active = PassState(hasPass: true)
    private let expired = PassState(hasPass: true, expired: true)
    private let none = PassState(hasPass: false)

    func testActivePassHidesAds() {
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: 7, pass: active), .hide)
    }
    func testNoPassOrExpiredPassShowsAds() {
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: 7, pass: none), .show)
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: 7, pass: expired), .show)
    }
    func testConfirmedNoRoomShowsAds() {
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: nil, pass: nil), .show)
    }
    func testUnknownNeverFlashesAds() {
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: false, roomId: nil, pass: nil), .unknown)
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: false, roomId: 7, pass: none), .unknown)
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: 7, pass: nil), .unknown)
        XCTAssertEqual(AdRules.gate(loggedIn: false, roomResolved: true, roomId: 7, pass: none), .unknown)
    }
    func testFeedAfterThirdThenEveryEight() {
        let after = (0..<30).filter { AdRules.adAfter(index: $0, count: 30, first: AdRules.feedFirst, every: AdRules.feedEvery) }
        XCTAssertEqual(after, [2, 10, 18, 26])
        XCTAssertEqual(after.map { AdRules.adSlot(index: $0, first: AdRules.feedFirst, every: AdRules.feedEvery) }, [0, 1, 2, 3])
    }
    func testBragAfterSecondThenEverySix() {
        let after = (0..<15).filter { AdRules.adAfter(index: $0, count: 15, first: AdRules.bragFirst, every: AdRules.bragEvery) }
        XCTAssertEqual(after, [1, 7, 13])
    }
    func testListNeverEndsWithAnAd() {
        XCTAssertFalse(AdRules.adAfter(index: 2, count: 3, first: AdRules.feedFirst, every: AdRules.feedEvery))
        XCTAssertTrue(AdRules.adAfter(index: 2, count: 4, first: AdRules.feedFirst, every: AdRules.feedEvery))
        XCTAssertFalse(AdRules.adAfter(index: 0, count: 0, first: AdRules.feedFirst, every: AdRules.feedEvery))
    }
    func testHomeAdOnlyOnMyHomeWithThisMonthCards() {
        XCTAssertTrue(AdRules.homeAdVisible(gate: .show, isMyPlan: true, thisMonthCount: 1, hasMoreBelow: true))
        XCTAssertFalse(AdRules.homeAdVisible(gate: .show, isMyPlan: true, thisMonthCount: 0, hasMoreBelow: true))
        XCTAssertFalse(AdRules.homeAdVisible(gate: .show, isMyPlan: false, thisMonthCount: 3, hasMoreBelow: true))
        XCTAssertFalse(AdRules.homeAdVisible(gate: .hide, isMyPlan: true, thisMonthCount: 3, hasMoreBelow: true))
        XCTAssertFalse(AdRules.homeAdVisible(gate: .unknown, isMyPlan: true, thisMonthCount: 3, hasMoreBelow: true))
    }
    func testHomeAdNeverEndsTheList() {
        XCTAssertFalse(AdRules.homeAdVisible(gate: .show, isMyPlan: true, thisMonthCount: 3, hasMoreBelow: false))
    }
}
