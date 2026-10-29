import XCTest

/// 일정 탭(달력)을 안드로이드 `CalendarScreen`(`PortParityShotTest#calendarHead` → `port-calendar`)과
/// 나란히 보려고 상태마다 찍는다 — 이번 달 · 그날 목록 · 빈 날 · 다음 달 · 보드.
final class CalendarParityUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch(); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func settle(_ seconds: TimeInterval = 1.2) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

    /// 조금만(관성 없이) 올린다. 끝까지 올리면 머리 면 제목이 상태바 시각 밑에 걸치고, 그대로 두면
    /// 마지막 줄이 탭바의 솟은 `+` 원에 닿는다 — 둘 다 아닌 자리에서 찍는다.
    private func nudgeUp(_ app: XCUIApplication, by points: CGFloat = 36) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -points)),
                    withVelocity: .slow, thenHoldForDuration: 0.4)
    }

    func testCalendarStates() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.schedule"].waitForExistence(timeout: 10))
        app.buttons["tab.schedule"].tap()
        XCTAssertTrue(app.buttons["calendar.next"].waitForExistence(timeout: 5))
        // 탭 화면에는 닫기·내보내기·떠 있는 + 가 없다(안드로이드와 같음).
        XCTAssertFalse(app.buttons["calendar.close"].exists)
        XCTAssertFalse(app.buttons["calendar.export"].exists)
        XCTAssertTrue(app.buttons["calendar.add"].exists)
        XCTAssertTrue(app.buttons["calendar.view.board"].exists)
        // 처음에는 보드(Android 8c1068b) — 달력 상태를 보려고 달력으로 바꾼다
        XCTAssertTrue(app.buttons["calendar.view.board"].isSelected, "일정 탭은 보드로 시작한다")
        app.buttons["calendar.view.calendar"].tap()
        settle()
        capture(app, "cal-month")

        // 그날 목록 — 오늘(일정 셋)
        let scroll = app.scrollViews["calendar.scroll"]
        scroll.swipeUp(); scroll.swipeUp(); settle()
        XCTAssertTrue(app.buttons["calendar.dayAdd"].exists)
        capture(app, "cal-month-daylist")

        // 일정이 없는 이번 달의 날 — "이 날은 비어 있어요"
        scroll.swipeDown(); settle(0.6)
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.day.'"))
        var tapped = false
        for index in 7..<min(days.count, 35) where !tapped {
            let cell = days.element(boundBy: index)
            let label = cell.label.trimmingCharacters(in: .whitespaces)
            if cell.isHittable, Int(label) != nil, !cell.isSelected, (Int(label) ?? 0) > 1, (Int(label) ?? 0) < 28 {
                cell.tap(); tapped = true
            }
        }
        XCTAssertTrue(tapped)
        settle()
        nudgeUp(app); settle()
        XCTAssertTrue(app.staticTexts["이 날은 비어 있어요"].exists)
        capture(app, "cal-empty-day")

        // 다음 달
        scroll.swipeDown(); scroll.swipeDown(); settle(0.6)
        app.buttons["calendar.next"].tap(); settle()
        nudgeUp(app); settle()
        capture(app, "cal-next")
        scroll.swipeDown(); settle(0.6)
        app.buttons["calendar.prev"].tap(); settle()

        // 보드
        app.buttons["calendar.view.board"].tap(); settle(1.5)
        capture(app, "cal-board")
        app.buttons["calendar.view.calendar"].tap(); settle()

        // 고른 날짜로 추가
        let add = app.buttons["calendar.add"]
        add.tap()
        XCTAssertTrue(app.textFields["addplan.title"].waitForExistence(timeout: 5))
        capture(app, "cal-add-date")
    }

    /// Android 는 일정 상세(`SCHEDULE_DETAIL`)와 거기서 연 수정하기(`ADD_PLAN`)에도 탭바를 둡니다.
    /// 예전 iOS 는 달력에서 연 상세를 전체 화면 창으로 띄워 탭바가 사라졌습니다.
    func testDetailFromCalendarKeepsTabBar() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.schedule"].waitForExistence(timeout: 10)); app.buttons["tab.schedule"].tap()
        // 처음에는 보드 — 그날 목록에서 여는 길을 보려고 달력으로
        XCTAssertTrue(app.buttons["calendar.view.calendar"].waitForExistence(timeout: 5)); app.buttons["calendar.view.calendar"].tap()
        let plan = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.plan.'")).firstMatch
        if !plan.waitForExistence(timeout: 5) {
            // 오늘에 일정이 없으면 일정 칩이 있는 날을 고른다
            let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.day.'"))
            for i in 0..<days.count {
                days.element(boundBy: i).tap()
                if plan.waitForExistence(timeout: 1) { break }
            }
        }
        XCTAssertTrue(plan.exists, "그날 목록에 일정이 있어야 한다")
        for _ in 0..<4 { if plan.isHittable { break }; nudgeUp(app, by: 200) }
        plan.tap()
        let title = app.descendants(matching: .any)["detail.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tab.home"].exists, "일정 상세에도 탭바가 남는다")
        settle()
        capture(app, "calendar-detail-tabbar")
        // 상세에서 수정하기 → 플랜 추가도 탭바가 남는다
        let edit = app.buttons["detail.edit"]
        for _ in 0..<6 { if edit.exists && edit.isHittable { break }; app.swipeUp() }
        edit.tap()
        XCTAssertTrue(app.textFields["addplan.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tab.add"].exists)
        // 탭을 누르면 상세·수정이 빠지고 그 탭이 처음부터 열린다
        app.buttons["tab.schedule"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar.title"].waitForExistence(timeout: 5))
        XCTAssertFalse(title.exists)
    }
}
