import XCTest

/// 청첩장 편집기의 계좌 입력 — 2026-10-19 사용자 실기기 보고(키보드가 안 내려감 · 미리보기가 밀려 적는 칸이 안 보임).
/// 시뮬레이터 캡처에는 키보드가 찍히지 않아 키보드 · 미리보기 · 패널의 자리는 프레임으로 본다.
final class InvitationEditorKeyboardUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openAccountsPanel() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPPassEnabled", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        app.buttons["explore.invitation"].tap()
        let primary = app.buttons["invitation.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        for _ in 0..<5 { if primary.isHittable { break }; app.swipeUp() }
        primary.tap()
        // 처음에는 구성 시트가 뜬다 — 계좌 입력을 고르고, 꺼 둔 칸이라 켠다
        let row = app.buttons["invitation.layout.accounts"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if row.isHittable { break }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        row.tap()
        let toggle = app.buttons["계좌 입력 보이기"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); toggle.tap()
        return app
    }

    private func waitKeyboardGone(_ app: XCUIApplication, _ message: String) {
        let e = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.element)
        wait(for: [e], timeout: 5)
        XCTAssertFalse(app.keyboards.element.exists, message)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testAccountTypingShowsLiveAndPreviewStaysPut() {
        let app = openAccountsPanel()
        let preview = app.scrollViews["invitation.editPreview"]
        let panel = app.scrollViews["invitation.panel"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5)); XCTAssertTrue(panel.waitForExistence(timeout: 5))
        sleep(1)
        let restFrame = preview.frame
        // 칸을 켜면 미리보기가 그 칸(마음 전하실 곳)으로 굴러 패널 위에 보인다
        let heading = preview.staticTexts["마음 전하실 곳"]
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(heading.frame.minY, restFrame.minY - 0.5)
        XCTAssertLessThanOrEqual(heading.frame.maxY, panel.frame.minY, "고르는 칸이 미리보기에 보여야 한다")

        // 예금주 — 한 글자라도 적으면 미리보기의 계좌 줄로 바로 보인다(저장 전)
        let name = app.textFields["invitation.account.0.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap()
        let keyboard = app.keyboards.element
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        // 공용 시뮬레이터는 하드웨어 키보드 취급이라 칸을 누르기만 하면 키보드가 화면 밖에 있다가, 글자를 치면(typeText) 올라온다 —
        // 자리는 친 뒤에 본다
        let screenHeight = XCUIScreen.main.screenshot().image.size.height
        func keyboardOnScreen(_ step: String) -> Bool {
            let on = keyboard.exists && keyboard.frame.height > 100 && keyboard.frame.minY < screenHeight - 100
            XCTContext.runActivity(named: "\(step) 키보드 화면에 있음: \(on) · \(keyboard.frame)") { _ in }
            return on
        }
        name.typeText("김우진"); sleep(1)
        let liveName = preview.staticTexts["김우진"]
        XCTAssertTrue(liveName.waitForExistence(timeout: 3), "적은 예금주가 미리보기에 바로 보여야 한다")
        _ = keyboardOnScreen("예금주")
        // 키보드가 떠도 미리보기 영역은 제자리 · 같은 높이
        XCTAssertEqual(preview.frame.minY, restFrame.minY, accuracy: 0.5, "키보드가 떠도 미리보기가 밀리면 안 된다")
        XCTAssertEqual(preview.frame.height, restFrame.height, accuracy: 0.5)

        // 계좌번호(전화 키패드) — 칸을 옮겨도 미리보기는 제자리, 적는 대로 바뀐다
        let number = app.textFields["invitation.account.0.number"]
        number.tap()
        number.typeText("110-123"); sleep(1)
        XCTAssertTrue(preview.staticTexts["110-123"].waitForExistence(timeout: 3), "적은 계좌번호가 미리보기에 바로 보여야 한다")
        let padOnScreen = keyboardOnScreen("계좌번호")
        capture(app, "invitation-accounts-typing")
        XCTContext.runActivity(named: "패널 \(panel.frame) · 계좌번호 칸 \(number.frame) · 미리보기 \(preview.frame)") { _ in }
        XCTAssertTrue(padOnScreen, "전화 키패드가 화면에 떠야 자리를 볼 수 있다")
        XCTAssertEqual(preview.frame.minY, restFrame.minY, accuracy: 0.5, "칸을 옮길 때 미리보기가 밀리면 안 된다")
        XCTAssertEqual(preview.frame.height, restFrame.height, accuracy: 0.5)
        // 적는 줄이 패널에 가리지 않고 미리보기에 보인다 · 적는 칸은 키보드 위에 있다
        let liveNumber = preview.staticTexts["110-123"]
        XCTAssertGreaterThanOrEqual(liveName.frame.minY, preview.frame.minY - 0.5)
        XCTAssertLessThanOrEqual(liveNumber.frame.maxY, panel.frame.minY - 50, "적는 계좌 줄이 패널 위로 보여야 한다")
        if padOnScreen {
            XCTAssertLessThanOrEqual(number.frame.maxY, keyboard.frame.minY + 0.5, "적는 칸이 키보드 위에 보여야 한다")
            // 패널 ScrollView 의 접근성 프레임은 흰 면(홈 표시줄까지)을 함께 잡아 바닥을 잴 수 없다 — 적는 칸으로 본다
        }

        // 미리보기를 누르면 내린다(앱 전체 `KeyboardDismiss` — 창 단위 바깥 누름)
        preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04)).tap()
        waitKeyboardGone(app, "미리보기를 누르면 키보드가 내려가야 한다")
        XCTAssertEqual(preview.frame.minY, restFrame.minY, accuracy: 0.5)
        XCTAssertTrue(preview.staticTexts["110-123"].exists, "내려도 적은 값은 미리보기에 남는다")
        capture(app, "invitation-accounts-keyboard-down")

        // 숫자(전화) 키패드의 완료로 내린다 — 리턴 키가 없는 키패드
        number.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let done = app.buttons["keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "숫자 키패드 위에 완료가 있어야 한다")
        done.tap()
        waitKeyboardGone(app, "완료를 누르면 키보드가 내려가야 한다")
        XCTAssertEqual(preview.frame.minY, restFrame.minY, accuracy: 0.5)
    }
}
