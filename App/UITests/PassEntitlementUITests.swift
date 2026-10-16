import StoreKitTest
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

    /// StoreKit 2 결제 — 스킴의 StoreKit 구성 파일(`App/Resources/WeddingPlant.storekit`, 대화상자 끔)로 년간을 사면 데모 서버가
    /// `/plan/pass/apple/verify` 에서 패스를 켜고, 시트·소개가 닫히며 홈으로 돌아가 프로필이 「년간 · 사용 중」을 보인다.
    func testStoreKitPurchaseTurnsPassOn() throws {
        // 지난 실행의 거래를 지우고 확인 창 없이 산다 — 테스트 세션이 시뮬레이터의 App Store 를 구성 파일로 바꾼다
        let session = try SKTestSession(configurationFileNamed: "WeddingPlant")
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let app = launch()
        openProfile(app)
        let entry = app.buttons["user.pass"]
        for _ in 0..<6 { if entry.exists && entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        let skip = app.webViews.buttons["건너뛰기"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10)); skip.tap()
        let web = app.webViews.firstMatch
        let plansLink = app.webViews.links["요금제 보기"]
        for _ in 0..<16 { if plansLink.exists && plansLink.isHittable { break }; web.swipeUp() }
        XCTAssertTrue(plansLink.isHittable); plansLink.tap()

        let buy = app.buttons["pass.buy"]
        XCTAssertTrue(buy.waitForExistence(timeout: 10))
        XCTAssertFalse(buy.isEnabled, "동의 전에는 결제 버튼이 잠겨 있다")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "준비하고 있어요")).firstMatch.exists)
        XCTAssertTrue(app.buttons["pass.restore"].exists, "평생 패스 구매 복원 링크(심사 지침 3.1.1)")
        app.buttons["pass.consent"].tap()
        // App Store(StoreKit 구성)의 상품이 와야 열린다 — 금액은 App Store 가 준 값
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: buy)
        waitForExpectations(timeout: 15)
        XCTAssertTrue(buy.label.contains("39,000원 결제하기"), buy.label)
        capture(app, "storekit-plans-ready")
        buy.tap()
        // 대화상자를 끈 구성이지만 기기 설정에 따라 확인 창이 뜨면 누른다
        for label in ["구입", "Purchase", "구독", "Subscribe", "확인", "OK"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 1) { button.tap(); break }
        }
        // 결제 → 서버 확인 → 시트·소개가 닫히고 홈으로
        XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 20))
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.descendants(matching: .any)["pass.intro"].firstMatch)
        waitForExpectations(timeout: 10)
        capture(app, "storekit-purchased-home")
        openProfile(app)
        XCTAssertTrue(app.staticTexts["년간 · 사용 중"].waitForExistence(timeout: 10), "산 패스가 프로필에 켜진다")
        XCTAssertFalse(app.buttons["user.pass"].exists)
        capture(app, "storekit-purchased-profile")
    }

    /// 구매 복원(심사 지침 3.1.1) — 평생 패스를 산 적이 없으면 "복원할 구매가 없어요." 를 회색 안내로 말한다(시트는 그대로).
    func testRestoreWithoutPurchasesSaysNothingToRestore() throws {
        let session = try SKTestSession(configurationFileNamed: "WeddingPlant")
        session.disableDialogs = true
        session.clearTransactions()
        let app = launch()
        openProfile(app)
        let entry = app.buttons["user.pass"]
        for _ in 0..<6 { if entry.exists && entry.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        let skip = app.webViews.buttons["건너뛰기"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10)); skip.tap()
        let web = app.webViews.firstMatch
        let plansLink = app.webViews.links["요금제 보기"]
        for _ in 0..<16 { if plansLink.exists && plansLink.isHittable { break }; web.swipeUp() }
        XCTAssertTrue(plansLink.isHittable); plansLink.tap()
        let restore = app.buttons["pass.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10)); restore.tap()
        XCTAssertTrue(app.staticTexts["복원할 구매가 없어요."].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["pass.buy"].exists)
        capture(app, "storekit-restore-nothing")
    }
}
