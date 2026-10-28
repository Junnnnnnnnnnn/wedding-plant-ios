import XCTest
@testable import WPDomain

/// Android `UpdateRulesTest`(373ec6f) — 새 버전이면 늘 안내, 같거나 낮으면 없음. iOS 는 버전 문자열을 비교한다.
final class UpdateRulesTests: XCTestCase {
    private let store = URL(string: "https://apps.apple.com/kr/app/id1")!

    func testNewerStoreVersionAlwaysOffers() {
        XCTAssertEqual(UpdateRules.decide(storeVersion: "1.0.2", storeURL: store, minimumOS: "17.0", installedVersion: "1.0.1", osVersion: "18.2"),
                       .init(version: "1.0.2", storeURL: store))
        XCTAssertNotNil(UpdateRules.decide(storeVersion: "1.0.10", storeURL: store, minimumOS: nil, installedVersion: "1.0.9", osVersion: "18.0"), "자리마다 숫자로")
    }

    func testSameOrOlderOrUnknownOffersNothing() {
        XCTAssertNil(UpdateRules.decide(storeVersion: "1.0.1", storeURL: store, minimumOS: nil, installedVersion: "1.0.1", osVersion: "18.0"))
        XCTAssertNil(UpdateRules.decide(storeVersion: "1.0.0", storeURL: store, minimumOS: nil, installedVersion: "1.0.1", osVersion: "18.0"), "스토어보다 새 TestFlight")
        XCTAssertNil(UpdateRules.decide(storeVersion: "1.1", storeURL: store, minimumOS: nil, installedVersion: "1.1.0", osVersion: "18.0"))
        XCTAssertNil(UpdateRules.decide(storeVersion: nil, storeURL: store, minimumOS: nil, installedVersion: "1.0.0", osVersion: "18.0"), "아직 스토어에 없음")
        XCTAssertNil(UpdateRules.decide(storeVersion: "2.0", storeURL: nil, minimumOS: nil, installedVersion: "1.0.0", osVersion: "18.0"))
    }

    func testVersionTheDeviceCannotInstallIsNotOffered() {
        XCTAssertNil(UpdateRules.decide(storeVersion: "2.0", storeURL: store, minimumOS: "19.0", installedVersion: "1.0.0", osVersion: "18.6"))
    }

    func testWordingMatchesAndroid() {
        XCTAssertEqual(UpdateRules.title, "새 버전이 나왔어요")
        XCTAssertEqual(UpdateRules.body, "고친 점과 새 기능이 담긴 버전이에요. 지금 업데이트할까요?")
        XCTAssertEqual([UpdateRules.update, UpdateRules.later], ["업데이트", "나중에"])
    }
}
