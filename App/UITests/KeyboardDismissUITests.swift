import XCTest

/// 키보드를 편하게 내리는 앱 전체 규칙(2026-10-19 사용자) — 플랜 추가 폼으로 확인한다.
/// 시뮬레이터 캡처에는 키보드가 찍히지 않아 `app.keyboards` 로 본다.
final class KeyboardDismissUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openForm() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.add"].waitForExistence(timeout: 10)); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("드레스 피팅")
        return app
    }

    private func waitKeyboardGone(_ app: XCUIApplication, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let gone = NSPredicate(format: "exists == false")
        let e = expectation(for: gone, evaluatedWith: app.keyboards.element)
        wait(for: [e], timeout: 5)
        XCTAssertFalse(app.keyboards.element.exists, message, file: file, line: line)
    }

    func testTapOutsideDismissesKeyboard() {
        let app = openForm()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        // 입력 칸이 아닌 머리 면을 누른다
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        waitKeyboardGone(app, "입력 칸 바깥을 누르면 키보드가 내려가야 한다")
    }

    func testDragDownDismissesKeyboard() {
        let app = openForm()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 300)))
        waitKeyboardGone(app, "폼을 아래로 끌면 키보드가 내려가야 한다")
    }

    func testNumberPadHasDoneButton() {
        let app = openForm()
        app.buttons["addplan.category"].tap()
        let tile = app.buttons.matching(identifier: "category.tile.드레스").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5)); tile.tap()
        app.buttons["category.confirm"].tap()
        let card = app.buttons["카드"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        let amount = app.descendants(matching: .any)["addplan.amount"].firstMatch
        for _ in 0..<4 { if amount.exists && amount.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); amount.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        let done = app.buttons["keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "숫자 키패드 위에 완료가 있어야 한다")
        done.tap()
        waitKeyboardGone(app, "완료를 누르면 키보드가 내려가야 한다")
    }
}
