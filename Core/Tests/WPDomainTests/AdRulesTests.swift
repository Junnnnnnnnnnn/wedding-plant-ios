import XCTest
import WPModels
@testable import WPDomain

final class AdRulesTests: XCTestCase {
    func testUnknownNeverFlashesAdsAndExpiredPassAllowsAds() {
        XCTAssertEqual(AdRules.gate(loggedIn: false, roomResolved: true, roomId: nil, pass: nil), .unknown)
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: false, roomId: nil, pass: nil), .unknown)
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: 1, pass: nil), .unknown)
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: nil, pass: nil), .show)
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: 1, pass: .init(hasPass: true)), .hide)
        XCTAssertEqual(AdRules.gate(loggedIn: true, roomResolved: true, roomId: 1, pass: .init(hasPass: true, expired: true)), .show)
    }
    func testAndroidInsertionPointsNeverEndAListWithAnAd() {
        XCTAssertEqual((0..<22).filter { AdRules.adAfter(index: $0, count: 22, first: 3, every: 8) }, [2, 10, 18])
        XCTAssertEqual((0..<15).filter { AdRules.adAfter(index: $0, count: 15, first: 2, every: 6) }, [1, 7, 13])
        XCTAssertFalse(AdRules.adAfter(index: 2, count: 3, first: 3, every: 8))
        XCTAssertFalse(AdRules.homeAdVisible(gate: .show, isMyPlan: false, thisMonthCount: 3, hasMoreBelow: true))
        XCTAssertFalse(AdRules.homeAdVisible(gate: .hide, isMyPlan: true, thisMonthCount: 3, hasMoreBelow: true))
        XCTAssertFalse(AdRules.homeAdVisible(gate: .show, isMyPlan: true, thisMonthCount: 3, hasMoreBelow: false))
        XCTAssertTrue(AdRules.homeAdVisible(gate: .show, isMyPlan: true, thisMonthCount: 3, hasMoreBelow: true))
    }
}
