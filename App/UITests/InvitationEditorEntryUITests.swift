import XCTest

/// 편집기를 여는 자리 — Android 2c2fb4c(v43) `InvitationEditorShotTest.newInvitationStartsWithLayout` ·
/// `layoutOpensFromPreview`. 새 청첩장은 구성 시트부터, **이미 있는 청첩장의 `고치기`는 미리보기부터** 열고 구성은 아래 단추로 연다.
final class InvitationEditorEntryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testNewStartsWithLayoutButExistingOpensPreview() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPPassEnabled", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        app.buttons["explore.invitation"].tap()
        let primary = app.buttons["invitation.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        for _ in 0..<5 { if primary.isHittable { break }; app.swipeUp() }
        primary.tap()

        // 새 청첩장 — 구성부터
        XCTAssertTrue(app.otherElements["invitation.layout"].waitForExistence(timeout: 5) || app.buttons["invitation.editCover"].waitForExistence(timeout: 1),
                      "새 청첩장은 구성 시트부터")
        capture(app, "inv-editor-new-layout")
        app.buttons["invitation.editCover"].tap()
        let groom = app.textFields["invitation.groom"], bride = app.textFields["invitation.bride"]
        XCTAssertTrue(groom.waitForExistence(timeout: 5)); groom.tap(); groom.typeText("현진"); bride.tap(); bride.typeText("미주")
        app.buttons["invitation.save"].tap()
        XCTAssertTrue(app.buttons["공개하러 가기"].waitForExistence(timeout: 10))
        app.buttons["공개하러 가기"].tap()

        // 이미 있는 청첩장 — 미리보기부터, 입력 칸도 구성 시트도 없다
        let edit = app.buttons["청첩장 고치기"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        for _ in 0..<5 { if edit.isHittable { break }; app.swipeUp() }
        edit.tap()
        XCTAssertTrue(app.scrollViews["invitation.editPreview"].waitForExistence(timeout: 5))
        let layoutPill = app.buttons["구성"]
        XCTAssertTrue(layoutPill.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["invitation.editCover"].waitForExistence(timeout: 2), "구성 시트가 저절로 뜨지 않는다")
        XCTAssertEqual(app.textFields.count, 0, "입력 패널도 열리지 않는다")
        capture(app, "inv-editor-preview-first")

        // 구성은 아래 단추로
        layoutPill.tap()
        XCTAssertTrue(app.buttons["invitation.editCover"].waitForExistence(timeout: 5), "구성 단추로 시트가 열린다")
        capture(app, "inv-editor-layout-from-pill")
    }
}
