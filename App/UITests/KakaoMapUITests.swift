import XCTest

/// 카카오맵(Android `KakaoMapView` 와 같은 SDK)이 지도 자리에 실제로 그려지는지 — 일정 상세 · 후기 상세 · 플랜 추가.
///
/// 타일은 카카오 서버에서 내려옵니다. 지도 자리에 "지도를 불러오지 못했어요" 가 보이면 앱 키 인증 실패
/// (콘솔의 iOS 번들 ID · [카카오맵] 활성화)이고, 캡처로 그 문구를 확인합니다.
final class KakaoMapUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func assertMapLoaded(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let map = app.descendants(matching: .any)["kakao.map"].firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 10), "지도 자리가 없다", file: file, line: line)
        // 타일을 받을 시간
        sleep(6)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '지도를 불러오지 못했어요'")).firstMatch.exists,
                       "카카오맵 인증·로딩 실패", file: file, line: line)
    }

    func testScheduleDetailMap() {
        let app = launch()
        let plan = app.staticTexts["드레스 1차 피팅"].firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        for _ in 0..<6 { if plan.isHittable { break }; app.swipeUp() }
        plan.tap()
        let map = app.descendants(matching: .any)["kakao.map"].firstMatch
        for _ in 0..<6 { if map.exists && map.isHittable { break }; app.swipeUp() }
        assertMapLoaded(app)
        capture(app, "kakao-map-schedule-detail")
    }

    func testFeedDetailMap() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        let card = app.staticTexts["라뮈에스튜디오"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        for _ in 0..<6 { if card.isHittable { break }; app.swipeUp() }
        card.tap()
        // 후기 상세의 지도는 손을 받지 않고(확인창을 거쳐 밖으로) 위의 누름 면이 이름을 든다 — 지도 자리는 그 면으로 찾는다
        XCTAssertTrue(app.descendants(matching: .any)["feed.detail.map"].firstMatch.waitForExistence(timeout: 10))
        sleep(6)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '지도를 불러오지 못했어요'")).firstMatch.exists, "카카오맵 인증·로딩 실패")
        capture(app, "kakao-map-feed-detail")
    }

    func testAddPlanMapTapPicksCoordinates() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.add"].waitForExistence(timeout: 10)); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("웨딩홀 투어\n")
        // 위치 칸은 카테고리 · 결제 유형을 고른 뒤에 열립니다(Android 와 같은 단계식 폼)
        let category = app.buttons["addplan.category"]
        XCTAssertTrue(category.waitForExistence(timeout: 5)); category.tap()
        let tile = app.buttons.matching(identifier: "category.tile.웨딩홀").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5)); tile.tap()
        app.buttons["category.confirm"].tap()
        let card = app.buttons["카드"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        let location = app.descendants(matching: .any)["addplan.location"].firstMatch
        for _ in 0..<6 { if location.exists && location.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(location.waitForExistence(timeout: 5)); location.tap(); location.typeText("서울시청\n")
        // 키보드 엔터만으로 검색된다(검색 버튼을 누르지 않음) — 2026-10-16 사용자 요청
        let result = app.staticTexts["서울특별시청"]
        XCTAssertTrue(result.waitForExistence(timeout: 5), "엔터를 누르면 바로 검색 결과가 떠야 한다")
        // 결과를 고르면 좌표가 잡힌다
        result.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '좌표 37.566'")).firstMatch.waitForExistence(timeout: 5),
                      "검색 결과를 고르면 그 좌표가 잡혀야 한다")
        let map = app.descendants(matching: .any)["kakao.map"].firstMatch
        for _ in 0..<6 { if map.exists && map.isHittable { break }; app.swipeUp() }
        assertMapLoaded(app)
        // 지도를 누르면 그 자리로 좌표가 바뀐다(검색 결과 좌표에서 벗어남)
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '좌표 ' AND NOT (label BEGINSWITH '좌표 37.56630')")).firstMatch.waitForExistence(timeout: 5),
                      "지도를 누르면 좌표가 바뀌어야 한다")
        capture(app, "kakao-map-addplan")
    }
}
