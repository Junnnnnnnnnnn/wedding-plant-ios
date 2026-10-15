import XCTest

/// Android `CategoryPickerSheet` 와 나란히 볼 캡처(port-picker-default · search · add)와, 긴 이름 타일의 글자 겹침 검사.
final class CategoryPickerParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    private func tile(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(identifier: "category.tile.\(name)").firstMatch
    }

    /// 타일 안 글자 줄이 서로 겹치지 않는지 — 이름 Text 의 높이가 줄 수 × 18 이상이어야 합니다
    private func assertNoOverlap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = tile(app, name)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "\(name) 타일 없음", file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.height, 66, file: file, line: line)
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        // 키보드의 검색(return) — 칸이 초점을 놓아 키보드가 내려갑니다
        app.textFields["category.search"].typeText("\n")
        sleep(1)
    }

    func testPickerMatchesAndroidStates() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.add"].waitForExistence(timeout: 10)); app.buttons["tab.add"].tap()
        // 제목을 적어야 카테고리 줄이 열립니다
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("신혼집 준비")
        let open = app.buttons["addplan.category"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))

        // 최근 선택을 Android 캡처와 같게(웨딩홀 · 드레스) 만든다
        for name in ["드레스", "웨딩홀"] {
            open.tap()
            let item = tile(app, name)
            XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
            app.buttons["category.confirm"].tap()
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            sleep(1)
        }
        open.tap()
        XCTAssertTrue(app.staticTexts["카테고리를 골라주세요"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["category.recent.웨딩홀"].exists)
        app.buttons["선택 해제"].tap()
        sleep(1)
        capture(app, "picker-default")

        // 검색 — Android port-picker-search 와 같은 상태(드레스를 고른 채 `청첩장`)
        tile(app, "드레스").tap()
        let search = app.textFields["category.search"]
        search.tap(); search.typeText("청첩장")
        XCTAssertTrue(app.staticTexts["한 개 선택"].waitForExistence(timeout: 5))
        for name in ["모바일 청첩장", "종이 청첩장", "청첩장 모임"] { assertNoOverlap(app, name) }
        // 키보드는 캡처에 찍히지 않으므로 바닥 줄이 키보드 위에 있는지는 프레임으로 봅니다
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(app.buttons["category.confirm"].frame.maxY, keyboard.frame.minY + 1)
        dismissKeyboard(app)
        capture(app, "picker-search")

        // 긴 이름 — `신혼여행 항공·교통` 이 두 줄로 꺾여도 겹치지 않게
        app.buttons["검색어 지우기"].tap()
        search.tap(); search.typeText("신혼여행")
        for name in ["신혼여행 항공·교통", "신혼여행 숙소", "신혼여행 경비"] { assertNoOverlap(app, name) }
        tile(app, "신혼여행 항공·교통").tap()
        dismissKeyboard(app)
        capture(app, "picker-search-long")

        // 직접 추가 — 검색어가 이름 칸에 미리 들어갑니다(Android 와 같음)
        app.buttons["검색어 지우기"].tap()
        search.tap(); search.typeText("청첩장")
        dismissKeyboard(app)
        app.buttons["category.add"].tap()
        XCTAssertTrue(app.staticTexts["우리만의 카테고리"].waitForExistence(timeout: 5))
        sleep(1)
        capture(app, "picker-add")

        // 없는 이름이면 새로 만들어 고르고, 목록으로 돌아와 안내합니다
        app.buttons["category.create"].tap()
        XCTAssertTrue(app.staticTexts["새 카테고리를 선택했어요. 선택 완료를 눌러 적용하세요."].waitForExistence(timeout: 5))
        XCTAssertTrue(tile(app, "청첩장").exists)
        capture(app, "picker-add-created")
    }

    /// Android 2026-10-12 사용자 보고와 같은 상황 — 목록을 내려 둔 채 머리를 잡고 끌어도 시트가 닫히지 않고, 목록이 맨 위로 간다.
    func testDraggingPinnedHeaderDoesNotCloseScrolledPicker() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.add"].waitForExistence(timeout: 10)); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("신혼집 준비\n")
        let open = app.buttons["addplan.category"]
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap()
        let heading = app.staticTexts["카테고리를 골라주세요"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let first = tile(app, "웨딩홀")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        // 목록을 내린다
        let list = app.scrollViews.element(boundBy: app.scrollViews.count - 1)
        list.swipeUp(); list.swipeUp()
        XCTAssertFalse(first.isHittable, "목록이 내려가 첫 타일이 가려져야 한다")
        // 붙여 둔 제목을 잡고 아래로 끈다
        let start = heading.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 260)))
        sleep(1)
        XCTAssertTrue(heading.exists, "목록을 내려 둔 채 머리를 끌면 시트가 닫히면 안 된다")
        XCTAssertTrue(first.waitForExistence(timeout: 3) && first.isHittable, "목록이 맨 위로 올라와야 한다")
    }
}
