import XCTest

/// Assertions for real navigation and state changes. DemoTransport isolates server mutations.
final class AndroidParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + arguments
        app.launch(); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testFiveTabsAndFilledAddReturnsToSchedule() {
        let app = launch()
        for tab in ["home", "schedule", "add", "explore", "rooms"] { XCTAssertTrue(app.buttons["tab.\(tab)"].waitForExistence(timeout: 10)) }
        app.buttons["tab.schedule"].tap()
        XCTAssertTrue(app.buttons["calendar.next"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["calendar.close"].exists)
        app.buttons["tab.add"].tap()
        XCTAssertTrue(app.textFields["addplan.title"].waitForExistence(timeout: 5))
        app.textFields["addplan.title"].tap(); app.textFields["addplan.title"].typeText("드레스 투어\n")
        let dress = app.buttons["드레스"].firstMatch
        XCTAssertTrue(dress.waitForExistence(timeout: 5)); dress.tap()
        let card = app.buttons["카드"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(app.textFields["addplan.amount"].waitForExistence(timeout: 5))
        capture(app, "parity-add")
        let close = app.buttons["addplan.back"]
        XCTAssertTrue(close.exists); close.tap()
        XCTAssertTrue(app.buttons["calendar.next"].waitForExistence(timeout: 5))
        app.buttons["tab.rooms"].tap()
        XCTAssertTrue(app.textFields["chat.input"].waitForExistence(timeout: 5))
        capture(app, "parity-chat-list")
    }
    func testSoloChatInviteAndCoupleManagement() {
        let app = launch(["-WPSolo"])
        app.buttons["tab.rooms"].tap()
        XCTAssertTrue(app.buttons["chat.invite"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["chat.input"].exists)
        capture(app, "parity-chat-solo")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-WPSolo" }; app.launch()
        app.buttons["tab.rooms"].tap()
        XCTAssertTrue(app.textFields["chat.input"].waitForExistence(timeout: 10))
        app.buttons["신랑 · 신부 관리"].tap()
        XCTAssertTrue(app.buttons["신랑 · 신부 해제"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["invite.reader"].exists)
        app.buttons["신랑 · 신부 해제"].tap()
        XCTAssertTrue(app.staticTexts["해제하면 신랑 · 신부가 이 플랜과 대화방에서 빠져요. 주고받은 대화와 일정은 남고, 초대 링크는 새로 바뀌어요."].waitForExistence(timeout: 5))
        capture(app, "parity-couple-unlink-confirm")
    }
    func testExploreHeadersAndBragNavigation() {
        let app = launch(); app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.staticTexts["다른 커플은 얼마 썼을까"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["내 후기 올리기"].exists)
        XCTAssertTrue(app.staticTexts["받은 도움"].exists)
        capture(app, "parity-explore-feed")
        app.buttons["explore.brag"].tap()
        XCTAssertTrue(app.staticTexts["다른 커플은 어떻게 준비했을까"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["올라온 플랜"].exists)
        capture(app, "parity-explore-brag")
    }
    func testFeedCopyPrefillsPlan() {
        let app = launch(); app.buttons["tab.explore"].tap()
        let copy = app.buttons["feed.copy.1"]
        XCTAssertTrue(copy.waitForExistence(timeout: 10))
        for _ in 0..<3 { if copy.isHittable { break }; app.swipeUp() }
        copy.tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "라뮈에스튜디오")
        XCTAssertTrue(app.buttons["addplan.category"].label.contains("스튜디오"))
        let cash = app.buttons["현금"]
        for _ in 0..<3 { if cash.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(cash.isHittable); cash.tap()
        let amount = app.textFields["addplan.amount"]
        for _ in 0..<3 { if amount.exists { break }; app.swipeUp() }
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "450")
        app.buttons["addplan.back"].tap()
        XCTAssertTrue(app.buttons["feed.copy.1"].waitForExistence(timeout: 5))
    }
    func testPassOpeningBenefitsAndNativePlans() {
        let app = launch()
        for _ in 0..<3 {
            app.buttons["main.profile"].tap()
            if app.buttons["user.pass"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.buttons["user.pass"].waitForExistence(timeout: 5)); app.buttons["user.pass"].tap()
        let skip = app.webViews.buttons["건너뛰기"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10)); skip.tap()
        let benefits = app.webViews.buttons["혜택 살펴보기"]
        XCTAssertTrue(benefits.waitForExistence(timeout: 8)); capture(app, "parity-pass-intro"); benefits.tap()
        XCTAssertTrue(app.webViews.buttons["플랜 등록·서류 첨부 시연 다시 보기"].waitForExistence(timeout: 10))
        capture(app, "parity-pass-docs-demo")
        for (label, name) in [("엑셀 정리", "excel"), ("결제일 알림", "reminders"), ("청첩장", "invitation")] {
            let chapter = app.webViews.buttons[label]
            XCTAssertTrue(chapter.waitForExistence(timeout: 5)); chapter.tap()
            // Let the section transition finish; the demonstration itself remains animated.
            Thread.sleep(forTimeInterval: 1)
            capture(app, "parity-pass-\(name)-demo")
        }
        app.webViews.links["요금제 보기"].tap()
        XCTAssertTrue(app.staticTexts["iOS 구매 연결을 준비하고 있어요. 이미 이용 중인 패스는 두 사람 모두 그대로 쓸 수 있어요."].waitForExistence(timeout: 5) || app.navigationBars["준비 패스"].exists)
        capture(app, "parity-pass-plans")
    }
    func testCalendarPDFExportReachesShareSheet() {
        assertExportShare(workbook: false)
    }
    func testCalendarWorkbookExportReachesShareSheet() {
        assertExportShare(workbook: true)
    }
    private func assertExportShare(workbook: Bool) {
        let app = launch(["-WPPassEnabled"]); app.buttons["tab.schedule"].tap(); app.buttons["calendar.export"].tap()
        let save = app.buttons["export.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        if workbook { app.buttons["엑셀"].tap() }
        for _ in 0..<4 { if save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5) || app.buttons["복사"].exists || app.otherElements["ActivityListView"].exists)
        capture(app, workbook ? "parity-export-workbook-share" : "parity-export-pdf-share")
    }
    func testSamplePDFPreviewWithoutPass() {
        let app = launch(); app.buttons["tab.schedule"].tap(); app.buttons["calendar.export"].tap()
        let sample = app.buttons["예시 데이터"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10)); sample.tap()
        let preview = app.buttons["export.preview"]
        for _ in 0..<5 { if preview.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(preview.isEnabled); preview.tap()
        XCTAssertTrue(app.buttons["document.close"].waitForExistence(timeout: 10))
        capture(app, "parity-export-sample-preview")
        app.buttons["document.close"].tap()
        XCTAssertTrue(app.buttons["export.preview"].waitForExistence(timeout: 5))
    }
    func testCategorySearchAndConfirmPreservesSelection() {
        let app = launch(); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("신혼집 준비")
        app.buttons["addplan.category"].tap()
        let search = app.textFields["category.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("신혼여행항공")
        let result = app.buttons["신혼여행 항공·교통"]
        XCTAssertTrue(result.waitForExistence(timeout: 5)); result.tap()
        capture(app, "parity-category-search")
        app.buttons["category.confirm"].tap()
        XCTAssertTrue(app.buttons["addplan.category"].label.contains("신혼여행 항공·교통"))
        app.buttons["addplan.category"].tap(); app.buttons["category.add"].tap()
        let name = app.textFields["category.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("우리만의 준비")
        app.buttons["category.create"].tap(); app.buttons["category.confirm"].tap()
        XCTAssertTrue(app.buttons["addplan.category"].label.contains("우리만의 준비"))
    }
    func testUpcomingPaymentsOpenReminderSettings() {
        let app = launch(["-WPPassEnabled"])
        let reminder = app.buttons["payment.reminders"]
        for _ in 0..<5 { if reminder.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(reminder.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["payment.4"].exists)
        XCTAssertTrue(app.buttons["payment.5"].exists)
        XCTAssertFalse(app.buttons["payment.3"].exists)
        capture(app, "parity-upcoming-payments")
        reminder.tap()
        XCTAssertTrue(app.buttons["reminder.lead.3"].waitForExistence(timeout: 5))
    }
    func testHomeBudgetProfileAndReminderSave() {
        let app = launch(["-WPPassEnabled"])
        XCTAssertTrue(app.buttons["main.budget"].waitForExistence(timeout: 10))
        capture(app, "parity-home-budget")
        app.buttons["main.profile"].tap()
        let reminders = app.buttons["결제일 알림 설정"]
        for _ in 0..<5 { if reminders.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(reminders.isHittable); reminders.tap()
        XCTAssertTrue(app.buttons["reminder.lead.3"].waitForExistence(timeout: 5))
        app.buttons["reminder.lead.3"].tap()
        capture(app, "parity-reminders")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "저장했어요")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["reminder.back"].tap()
        XCTAssertTrue(app.buttons["결제일 알림 설정"].waitForExistence(timeout: 5))
    }
    func testCreatePlanShowsBloomBeforeReturning() {
        let app = launch(); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("스튜디오 계약")
        let category = app.buttons["스튜디오"].firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 5)); category.tap()
        let cash = app.buttons["현금"]
        for _ in 0..<3 { if cash.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(cash.isHittable); cash.tap()
        XCTAssertTrue(app.buttons["addplan.save"].isEnabled); app.buttons["addplan.save"].tap()
        XCTAssertTrue(app.staticTexts["플랜이 등록되었어요"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["bloom.close"].exists)
        capture(app, "parity-bloom-created")
        app.buttons["bloom.close"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
    }
    func testOnboardingPermissionsCanBeSkipped() {
        let app = launch(["-WPForceOnboarding"])
        let next = app.buttons["setting.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10)); next.tap()
        let budget = app.textFields["setting.budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5)); budget.tap(); budget.typeText("5000"); next.tap()
        let name = app.textFields["setting.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("지수"); next.tap()
        let agree = app.buttons["setting.agreeAll"]
        XCTAssertTrue(agree.waitForExistence(timeout: 10)); agree.tap()
        let submit = app.buttons["setting.submit"]
        for _ in 0..<3 { if submit.isHittable { break }; app.swipeUp() }
        submit.tap()
        let permissionNext = app.buttons["setting.permissions.next"]
        XCTAssertTrue(permissionNext.waitForExistence(timeout: 10))
        capture(app, "parity-onboarding-permissions")
        let later = app.buttons["setting.permissions.later"]
        if later.exists { later.tap() } else { permissionNext.tap() }
        XCTAssertTrue(app.buttons["setting.inviteLater"].waitForExistence(timeout: 5))
        app.buttons["setting.inviteLater"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10))
    }
    func testEditAndDeletePlanShowBloom() {
        let app = launch(["-WPPassEnabled"])
        let plan = app.staticTexts["드레스 1차 피팅"].firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        for _ in 0..<6 { if plan.isHittable { break }; app.swipeUp() }
        plan.tap()
        let edit = app.buttons["수정하기"]
        for _ in 0..<8 { if edit.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(edit.isHittable)
        // Attach/delete belong in the editor; details only allow document viewing.
        XCTAssertFalse(app.buttons["파일 첨부"].exists)
        edit.tap()
        XCTAssertTrue(app.textFields["addplan.title"].waitForExistence(timeout: 5))
        let save = app.buttons["addplan.save"]
        for _ in 0..<12 { if save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(app.staticTexts["플랜이 수정되었어요"].waitForExistence(timeout: 10))
        capture(app, "parity-bloom-updated"); app.buttons["bloom.close"].tap()
        let delete = app.buttons["detail.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        for _ in 0..<8 { if delete.isHittable { break }; app.swipeUp() }
        delete.tap()
        XCTAssertTrue(app.staticTexts["이 플랜을 삭제할까요?"].waitForExistence(timeout: 5))
        app.buttons["detail.confirmDelete"].tap()
        XCTAssertTrue(app.staticTexts["플랜이 삭제되었어요"].waitForExistence(timeout: 10))
        capture(app, "parity-bloom-deleted"); app.buttons["bloom.close"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
    }
    func testEmailLoginAndValidation() {
        let app = launch(["-WPLoggedOut"])
        XCTAssertTrue(app.buttons["auth.email"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["auth.google"].exists); XCTAssertTrue(app.buttons["auth.apple"].exists)
        capture(app, "parity-landing")
        app.buttons["auth.email"].tap()
        let email = app.textFields["email.address"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        let close = app.buttons["email.close"]
        XCTAssertTrue(close.exists)
        let heading = app.staticTexts["email.title"]
        XCTAssertLessThan(abs(heading.frame.midY - close.frame.midY), 4, "Title and close share one header row")
        capture(app, "email-compact-initial")
        email.tap(); email.typeText("invalid")
        app.buttons["email.submit"].tap()
        XCTAssertTrue(app.staticTexts["email.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["email.submit"].isHittable)
        capture(app, "email-compact-validation")
        email.tap(); email.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "member@example.com")
        app.buttons["email.submit"].tap()
        let password = app.secureTextFields["email.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5)); password.tap(); password.typeText("test-password")
        XCTAssertTrue(app.buttons["email.submit"].isHittable)
        capture(app, "parity-email-password")
        app.buttons["email.submit"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10))
    }
    func testEmailSignupAndPasswordResetFitSheet() {
        let app = launch(["-WPLoggedOut"])
        XCTAssertTrue(app.buttons["auth.email"].waitForExistence(timeout: 10)); app.buttons["auth.email"].tap()
        let email = app.textFields["email.address"]
        XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("new-member@example.com")
        app.buttons["email.submit"].tap()
        let code = app.textFields["email.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("123456")
        let password = app.secureTextFields["email.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5)); password.tap(); password.typeText("new-password")
        XCTAssertTrue(app.buttons["email.submit"].isHittable)
        capture(app, "email-compact-signup")
        app.buttons["email.close"].tap()
        app.buttons["auth.email"].tap()
        XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("member@example.com")
        app.buttons["email.submit"].tap()
        let forgot = app.buttons["비밀번호를 잊으셨나요?"]
        XCTAssertTrue(forgot.waitForExistence(timeout: 5)); forgot.tap()
        XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("123456")
        password.tap(); password.typeText("updated-password")
        XCTAssertTrue(app.buttons["email.submit"].isHittable)
        capture(app, "email-compact-reset")
        app.buttons["email.submit"].tap()
        XCTAssertTrue(app.staticTexts["비밀번호를 바꿨어요"].waitForExistence(timeout: 5))
        app.buttons["email.submit"].tap()
        XCTAssertTrue(password.waitForExistence(timeout: 5))
    }
    func testInvitationLandingMotionAndPreview() {
        let app = launch(); app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.buttons["explore.invitation"].waitForExistence(timeout: 5)); app.buttons["explore.invitation"].tap()
        XCTAssertTrue(app.otherElements["invitation.garden"].waitForExistence(timeout: 10))
        capture(app, "parity-garden-start")
        // Typewriter's second line triggers the drop. Attach frames throughout the flight.
        Thread.sleep(forTimeInterval: 4.2)
        for index in 0..<8 { capture(app, "parity-garden-flight-\(index)"); Thread.sleep(forTimeInterval: 0.25) }
        for _ in 0..<4 { if app.buttons["예시 청첩장 구경하기"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.buttons["예시 청첩장 구경하기"].isHittable); app.buttons["예시 청첩장 구경하기"].tap()
        XCTAssertTrue(app.buttons["invitation.replay"].waitForExistence(timeout: 5))
        app.buttons["invitation.replay"].tap()
        Thread.sleep(forTimeInterval: 3.2)
        XCTAssertTrue(app.staticTexts["우리의 계절이 피어나는 날"].firstMatch.waitForExistence(timeout: 5))
        capture(app, "parity-invitation-preview")
    }
    func testInvitationCreateSaveAndPublish() {
        let app = launch(["-WPPassEnabled"]); app.buttons["tab.explore"].tap(); app.buttons["explore.invitation"].tap()
        XCTAssertTrue(app.buttons["invitation.primary"].waitForExistence(timeout: 10))
        for _ in 0..<5 { if app.buttons["invitation.primary"].isHittable { break }; app.swipeUp() }
        app.buttons["invitation.primary"].tap()
        XCTAssertTrue(app.buttons["invitation.editCover"].waitForExistence(timeout: 5))
        app.buttons["invitation.editCover"].tap()
        let groom = app.textFields["invitation.groom"], bride = app.textFields["invitation.bride"]
        XCTAssertTrue(groom.waitForExistence(timeout: 5)); groom.tap(); groom.typeText("우진"); bride.tap(); bride.typeText("채원")
        capture(app, "parity-invitation-editor")
        app.buttons["invitation.save"].tap()
        XCTAssertTrue(app.buttons["공개하러 가기"].waitForExistence(timeout: 10)); app.buttons["공개하러 가기"].tap()
        XCTAssertTrue(app.buttons["청첩장 고치기"].waitForExistence(timeout: 10))
        for _ in 0..<5 { if app.buttons["공개하고 링크 받기"].isHittable { break }; app.swipeUp() }
        app.buttons["공개하고 링크 받기"].tap()
        app.buttons.matching(identifier: "공개하기").allElementsBoundByIndex.last!.tap()
        XCTAssertTrue(app.buttons["invitation.address"].waitForExistence(timeout: 10))
        capture(app, "parity-invitation-published")
    }
}
