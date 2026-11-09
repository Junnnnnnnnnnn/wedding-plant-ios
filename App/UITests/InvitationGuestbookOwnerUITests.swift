import XCTest

/// 청첩장 주인의 축하 글 보기 · 고치기 · 지우기(2026-11-09 시안 `weddingplant-guestbook` ①②③).
/// 데모 서버(`-WPInvitationPublished`)가 공개 중인 청첩장과 축하 글 8개, 주인용 목록 · 고치기 · 지우기를 흉내 낸다.
final class InvitationGuestbookOwnerUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testOwnerSeesEditsAndDeletesWishes() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPPassEnabled", "-WPInvitationPublished", "-WPInvitationGuestsTotal", "8",
                               "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        app.buttons["explore.invitation"].tap()

        // ① 정원 아래 줄
        let row = app.buttons["invitation.guestbookRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        for _ in 0..<4 { if row.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["축하 글 8개"].waitForExistence(timeout: 5))
        capture(app, "guestbook-1-row")

        // ② 시트 — 검색 · 고치기 · 지우기
        row.tap()
        XCTAssertTrue(app.textFields["guestbook.search"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["guestbook.edit.w0"].waitForExistence(timeout: 10))
        capture(app, "guestbook-2-sheet")
        let search = app.textFields["guestbook.search"]
        search.tap(); search.typeText("도윤")
        XCTAssertFalse(app.buttons["guestbook.edit.w0"].exists, "하은 글은 걸러진다")
        XCTAssertTrue(app.buttons["guestbook.edit.w1"].exists)
        capture(app, "guestbook-3-search")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        XCTAssertTrue(app.buttons["guestbook.edit.w0"].waitForExistence(timeout: 5))

        app.buttons["guestbook.edit.w0"].tap()
        let message = app.textFields["guestbook.editMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()
        message.typeText(" 고침")
        let edited = (message.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(edited.contains("고침"))
        capture(app, "guestbook-4-edit")
        app.buttons["guestbook.editSave"].tap()
        XCTAssertTrue(app.staticTexts[edited].waitForExistence(timeout: 10), "고친 글이 목록에 보인다")
        capture(app, "guestbook-5-edited")

        app.buttons["guestbook.delete.w1"].tap()
        XCTAssertTrue(app.staticTexts["이 축하 글을 지울까요? 되돌릴 수 없어요."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["그대로 두기"].exists)
        capture(app, "guestbook-6-delete-confirm")
        app.alerts.buttons["지우기"].tap()
        XCTAssertTrue(app.staticTexts["축하 글 7개"].waitForExistence(timeout: 10), "지운 뒤 총수가 줄어든다")
        XCTAssertFalse(app.buttons["guestbook.edit.w1"].exists)
        capture(app, "guestbook-7-deleted")
        app.buttons["닫기"].tap()

        // ③ 하객 화면 미리보기의 펼친 목록
        let preview = app.buttons["하객 화면"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        for _ in 0..<5 { if preview.isHittable { break }; app.swipeUp() }
        preview.tap()
        let toggle = app.buttons["invitation.guestbookToggle"]
        for _ in 0..<25 { if toggle.exists && toggle.isHittable { break }; app.swipeUp() }
        toggle.tap()
        XCTAssertTrue(app.staticTexts["목록 접기"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts[edited].waitForExistence(timeout: 5), "실제 축하 글이 펼쳐진다")
        capture(app, "guestbook-8-preview-expanded")
    }
}
