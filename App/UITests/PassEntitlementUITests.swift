import XCTest

final class PassEntitlementUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ args: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPAdPreview", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + args
        app.launch()
        XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 10))
        return app
    }
    private func openProfile(_ app: XCUIApplication) {
        for _ in 0..<3 {
            app.buttons["main.profile"].tap()
            if app.textFields["user.name"].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Profile did not open")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    /// Android 와 같게 — 패스가 끝나도 청첩장은 남으므로 홈에 정원 카드가 뜹니다(빈 정원은 아님).
    func testUnpaidExistingInvitationShowsHomeGarden() {
        let app = launch(["-WPExistingInvitation"])
        let garden = app.descendants(matching: .any)["main.invitationGarden"].firstMatch
        XCTAssertTrue(garden.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["main.invitationCreate"].exists, "내 청첩장이 있으면 만들기가 아니라 보기")
        XCTAssertFalse(app.descendants(matching: .any)["main.invitationRow"].exists)
        capture(app, "unpaid-existing-invitation-home")
        openProfile(app)
        XCTAssertTrue(app.buttons["user.pass"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["우리 둘, 준비 패스와 함께"].exists)
        capture(app, "unpaid-profile-pass-card")
    }
    func testLifetimeProfileAndCompactPlans() {
        let app = launch(["-WPPassEnabled", "-WPLifetimePass"])
        XCTAssertTrue(app.descendants(matching: .any)["main.invitationGarden"].firstMatch.waitForExistence(timeout: 10))
        openProfile(app)
        XCTAssertTrue(app.buttons["pass.plans"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["기간 제한 없음"].exists)
        XCTAssertFalse(app.buttons["user.pass"].exists)
        capture(app, "lifetime-profile-tools")
        app.buttons["pass.plans"].tap()
        XCTAssertTrue(app.staticTexts["평생 이용 중"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["pass.plan.prep_pass_yearly"].exists)
        capture(app, "lifetime-compact-plans")
        app.buttons["pass.closePlans"].tap()
        app.buttons["pass.reminder"].tap()
        XCTAssertTrue(app.staticTexts["결제일 알림"].firstMatch.waitForExistence(timeout: 10))
    }
    func testUnpaidDocumentCardHasPassEntry() {
        let app = launch()
        let plan = app.staticTexts["드레스 1차 피팅"].firstMatch
        for _ in 0..<8 { if plan.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(plan.isHittable); plan.tap()
        let cta = app.buttons["documents.pass"]
        for _ in 0..<8 { if cta.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(cta.isHittable)
        XCTAssertFalse(app.staticTexts["사진 · 서류"].exists)
        XCTAssertFalse(app.buttons["전부 내려받기"].exists)
        capture(app, "unpaid-document-card")
        cta.tap()
        XCTAssertTrue(app.webViews.buttons["건너뛰기"].waitForExistence(timeout: 10))
    }
    func testPaidReadOnlyDocumentsHaveNoUploadOrEmptyDownload() {
        let app = launch(["-WPPassEnabled"])
        let plan = app.staticTexts["드레스 1차 피팅"].firstMatch
        for _ in 0..<8 { if plan.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(plan.isHittable); plan.tap()
        let note = app.staticTexts["방장·배우자만 볼 수 있어요 · 서류는 수정하기에서 붙이고 지워요"]
        for _ in 0..<8 { if note.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(note.isHittable)
        XCTAssertFalse(app.buttons["documents.pass"].exists)
        XCTAssertFalse(app.buttons["사진 올리기"].exists)
        XCTAssertFalse(app.buttons["전부 내려받기"].exists)
        capture(app, "paid-document-card")
    }
}
