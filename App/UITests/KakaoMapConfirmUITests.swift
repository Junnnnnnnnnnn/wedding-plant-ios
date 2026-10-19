import XCTest

/// Android 2e0cb94 · 558f031 — 후기 상세의 지도는 누르면 `카카오맵으로 이동할까요?` 를 묻고,
/// 청첩장의 오시는 길은 주소를 적으면 카카오 지도가 그 자리에 선다.
final class KakaoMapConfirmUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + extra
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testFeedMapAsksBeforeLeaving() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        let card = app.staticTexts["라뮈에스튜디오"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        for _ in 0..<6 { if card.isHittable { break }; app.swipeUp() }
        card.tap()
        XCTAssertFalse(app.staticTexts["카카오맵에서 열기"].exists, "예전 알약 단추는 없다 — 지도 자체를 누른다")
        let map = app.descendants(matching: .any)["feed.detail.map"].firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        map.tap()
        XCTAssertTrue(app.staticTexts["카카오맵으로 이동할까요?"].waitForExistence(timeout: 3))
        capture(app, "feed-map-confirm")
        app.buttons["feed.map.cancel"].tap()
        XCTAssertFalse(app.staticTexts["카카오맵으로 이동할까요?"].waitForExistence(timeout: 1), "취소하면 닫힌다")
        XCTAssertTrue(map.exists, "상세에서 나가지 않는다")
        // 바깥(딤)을 눌러도 닫힌다
        map.tap()
        XCTAssertTrue(app.staticTexts["카카오맵으로 이동할까요?"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        XCTAssertFalse(app.staticTexts["카카오맵으로 이동할까요?"].waitForExistence(timeout: 1))
    }

    func testInvitationLocationShowsKakaoMap() {
        let app = launch(["-WPPassEnabled"])
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        app.buttons["explore.invitation"].tap()
        let primary = app.buttons["invitation.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        for _ in 0..<5 { if primary.isHittable { break }; app.swipeUp() }
        primary.tap()
        let row = app.buttons["invitation.layout.location"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if row.isHittable { break }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        row.tap()
        XCTAssertTrue(app.staticTexts["두 사람에게 오는 길"].waitForExistence(timeout: 5), "주소가 없으면 안내 자리")
        XCTAssertTrue(app.staticTexts["주소를 적으면 카카오 지도가 표시돼요. 하객 화면에서 지도나 버튼을 누르면 카카오맵으로 이어져요."].exists)
        app.buttons["카카오맵에서 찾기"].tap()
        let field = app.textFields["예식장 이름이나 주소"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("서울시청")
        let result = app.buttons.containing(NSPredicate(format: "label CONTAINS '서울특별시청'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5)); result.tap()
        let preview = app.scrollViews["invitation.editPreview"]
        // 지도는 손을 받지 않고(접근성에서도 숨김) 위의 누름 면이 이름을 든다
        XCTAssertTrue(preview.buttons["서울특별시청 카카오 지도"].waitForExistence(timeout: 5))
        let loading = preview.staticTexts["지도를 불러오고 있어요"]
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: loading)
        wait(for: [gone], timeout: 15)
        XCTAssertFalse(preview.staticTexts["카카오 지도에서 위치 보기"].exists, "주소를 좌표로 바꿔 카카오 지도를 세운다(못 찾으면 이 안내)")
        sleep(6)
        XCTAssertTrue(preview.buttons["카카오 지도"].exists, "네이버 지도 대신 카카오 지도 단추")
        XCTAssertFalse(preview.buttons["네이버 지도"].exists)
        capture(app, "invitation-location-map")
    }
}
