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
    private func captureScreen(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    /// Android `PortParityShotTest.addPlanBlankTapHidesKeyboard` 의 `addplan-keyboard-up` 과 같은 상태 —
    /// 제목 `드레스 투어` · 카테고리 `드레스` · 결제 유형 줄이 보이고, 제목을 눌러 키보드가 올라온 화면.
    /// (Android 는 피드에서 채워 온 값이라 추천 칩 줄이 남고, 여기서는 칩으로 골라 줄이 접힌다 — Android 도 칩으로 고르면 접힌다.)
    func testAddPlanTitleKeyboardMatchesAndroid() {
        let app = launch(); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap()
        // 키보드가 화면에 올라오면 탭바를 내린다(Android `showTabBar = onTabScreen && !imeVisible`).
        // 시뮬레이터는 한 번 글자를 친 뒤로는 키보드를 화면 밖에 두기도 해서(하드웨어 키보드 취급) 화면에 있을 때만 본다.
        assertTabBarHiddenWhileKeyboardOnScreen(app)
        title.typeText("드레스 투어\n")
        let chip = app.buttons["addplan.suggest.드레스"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5)); chip.tap()
        XCTAssertTrue(app.buttons["카드"].waitForExistence(timeout: 5))
        // 칩으로 고르면 추천 줄이 접힌다(Android `categorySelectedByUser`)
        XCTAssertFalse(app.buttons["addplan.suggest.드레스"].waitForExistence(timeout: 2))
        title.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5)); sleep(1)
        assertTabBarHiddenWhileKeyboardOnScreen(app)
        // 이 시뮬레이터 캡처에는 키보드가 찍히지 않아(빈 흰 여백) 키보드 위 배치는 프레임으로 본다 —
        // 제목·카테고리·결제 유형 칩이 키보드 위에 그대로 보여야 한다(Android `addplan-keyboard-up`).
        for element in [title, app.buttons["addplan.category"], app.buttons["카드"]] {
            XCTAssertTrue(element.isHittable)
            XCTAssertLessThanOrEqual(element.frame.maxY, keyboard.frame.minY)
        }
        // 키보드를 내린 뒤 찍는다(Android `addplan-keyboard-down` 과 같은 화면)
        title.typeText("\n")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: keyboard)
        waitForExpectations(timeout: 5)
        sleep(1)
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 3))
        capture(app, "parity-addplan-keyboard-down")
    }
    /// 키보드가 화면에 올라와 있으면 탭바가 없고, 화면 밖(하드웨어 키보드 취급)이면 탭바가 그대로다 —
    /// Android `showTabBar = onTabScreen && !imeVisible`. 공용 시뮬레이터는 상태에 따라 키보드를 화면 밖에 두기도 해서 둘 다 본다.
    private func assertTabBarHiddenWhileKeyboardOnScreen(_ app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.waitForExistence(timeout: 5) else { return }
        sleep(1)
        let onScreen = keyboard.frame.minY < app.windows.firstMatch.frame.maxY - 1
        XCTContext.runActivity(named: "키보드 화면에 있음: \(onScreen)") { _ in
            XCTAssertEqual(app.buttons["tab.home"].exists, !onScreen)
        }
    }
    func testFiveTabsAndFilledAddReturnsToSchedule() {
        let app = launch()
        for tab in ["home", "schedule", "add", "explore", "rooms"] { XCTAssertTrue(app.buttons["tab.\(tab)"].waitForExistence(timeout: 10)) }
        app.buttons["tab.schedule"].tap()
        XCTAssertTrue(app.buttons["calendar.next"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["calendar.close"].exists)
        capture(app, "review-calendar-month")
        app.buttons["tab.add"].tap()
        XCTAssertTrue(app.textFields["addplan.title"].waitForExistence(timeout: 5))
        // 플랜 추가에도 탭바가 남고 가운데 `+` 가 켜진다(Android `onTabScreen` 의 ADD_PLAN · `fromRoute = ADD`)
        XCTAssertTrue(app.buttons["tab.home"].exists)
        XCTAssertTrue(app.buttons["tab.add"].isSelected)
        XCTAssertFalse(app.buttons["tab.schedule"].isSelected)
        capture(app, "review-add-empty")
        app.textFields["addplan.title"].tap(); app.textFields["addplan.title"].typeText("드레스 투어\n")
        capture(app, "review-add-title-keyboard")
        let dress = app.buttons["드레스"].firstMatch
        XCTAssertTrue(dress.waitForExistence(timeout: 5)); dress.tap()
        let card = app.buttons["카드"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        XCTAssertTrue(app.textFields["addplan.amount"].waitForExistence(timeout: 5))
        capture(app, "parity-add")
        let close = app.buttons["addplan.back"]
        XCTAssertTrue(close.exists); close.tap()
        // 누른 화면(일정)으로 돌아온다
        XCTAssertTrue(app.buttons["calendar.next"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["addplan.title"].exists)
        XCTAssertTrue(app.buttons["tab.schedule"].isSelected)
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
        capture(app, "review-couple-management")
        // 안드로이드 `CoupleSection` — 해제는 시스템 확인창이 아니라 상자 안에서 한 번 더 묻는다
        let unlink = app.buttons["couple.unlink"]
        for _ in 0..<4 { if unlink.waitForExistence(timeout: 2), unlink.isHittable { break }; app.swipeUp() }
        XCTAssertFalse(app.buttons["invite.reader"].exists)
        unlink.tap()
        XCTAssertTrue(app.buttons["couple.confirm"].waitForExistence(timeout: 5))
        capture(app, "parity-couple-unlink-confirm")
    }
    func testExploreHeadersAndBragNavigation() {
        let app = launch(); app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.staticTexts["다른 커플은 얼마 썼을까"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["feed.post.open"].exists)
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
            capture(app, "review-profile-top")
            if app.buttons["user.pass"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.buttons["user.pass"].waitForExistence(timeout: 5)); app.buttons["user.pass"].tap()
        let skip = app.webViews.buttons["건너뛰기"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10)); skip.tap()
        // 소개는 그냥 스크롤되는 문서다(2026-10-16 사용자 — 스크롤 거리로 장면을 넘기지 않는다).
        // 그래서 「혜택 살펴보기」 단추 없이 아래로 밀면 혜택 섹션이 이어서 보인다.
        sleep(2); capture(app, "parity-pass-intro")
        let web = app.webViews.firstMatch
        for i in 1...4 {
            web.swipeUp(velocity: .slow); sleep(1)
            capture(app, "parity-pass-flow-scroll-\(i)")
        }
        let plansLink = app.webViews.links["요금제 보기"]
        for _ in 0..<12 { if plansLink.exists && plansLink.isHittable { break }; web.swipeUp() }
        XCTAssertTrue(plansLink.isHittable, "아래로 밀면 끝에 요금제 보기가 나와야 한다")
        app.webViews.links["요금제 보기"].tap()
        // 요금제 시트 — 결제 버튼은 동의 + App Store 상품을 받은 뒤에 열린다(StoreKit 2)
        XCTAssertTrue(app.buttons["pass.buy"].waitForExistence(timeout: 5))
        capture(app, "parity-pass-plans")
    }
    func testCalendarPDFExportReachesShareSheet() {
        assertExportShare(workbook: false)
    }
    func testCalendarWorkbookExportReachesShareSheet() {
        assertExportShare(workbook: true)
    }
    private func assertExportShare(workbook: Bool) {
        let app = launch(["-WPPassEnabled"]); openExport(app)
        let save = app.buttons["export.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        app.buttons[workbook ? "엑셀" : "PDF"].tap()
        for _ in 0..<4 { if save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.isEnabled); capture(app, "review-edit-ready"); save.tap()
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5) || app.buttons["복사"].exists || app.otherElements["ActivityListView"].exists)
        capture(app, workbook ? "parity-export-workbook-share" : "parity-export-pdf-share")
    }
    /// 폰의 일정 탭에는 내보내기 버튼이 없다(안드로이드·웹 폰과 같음) — 프로필의 준비 패스 도구 `엑셀 받기` 로 연다.
    private func openExport(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 10))
        app.buttons["main.profile"].tap()
        let export = app.buttons["엑셀 받기"]
        for _ in 0..<6 { if export.waitForExistence(timeout: 2), export.isHittable { break }; app.swipeUp() }
        export.tap()
    }
    /// 안드로이드 `export-preview-pdf` — 시트 안의 양식 미리보기를 예시 데이터 · PDF 로 본다(파일을 만들지 않는다).
    func testSamplePDFPreviewWithoutPass() {
        let app = launch(["-WPPassEnabled"]); openExport(app)
        let pdf = app.buttons["PDF"]
        XCTAssertTrue(pdf.waitForExistence(timeout: 10)); pdf.tap()
        app.buttons["export.template.budget"].tap()
        let scroll = app.scrollViews["export.scroll"]
        let sample = app.buttons["예시 데이터"]
        for _ in 0..<4 { if sample.isHittable { break }; scroll.swipeUp() }
        sample.tap()
        XCTAssertTrue(app.staticTexts["예시 데이터로 양식을 확인해 보세요"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["export.save"].isEnabled)
        capture(app, "parity-export-sample-preview")
    }
    func testCategorySearchAndConfirmPreservesSelection() {
        let app = launch(); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("신혼집 준비")
        app.buttons["addplan.category"].tap()
        let search = app.textFields["category.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); capture(app, "review-category-default"); search.tap(); search.typeText("신혼여행항공")
        let result = app.buttons["신혼여행 항공·교통"]
        XCTAssertTrue(result.waitForExistence(timeout: 5)); result.tap()
        capture(app, "parity-category-search")
        app.buttons["category.confirm"].tap()
        XCTAssertTrue(app.buttons["addplan.category"].label.contains("신혼여행 항공·교통"))
        app.buttons["addplan.category"].tap(); app.buttons["category.add"].tap()
        let name = app.textFields["category.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("우리만의 준비")
        capture(app, "review-category-create")
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
        capture(app, "review-profile-top")
        // 안드로이드처럼 결제일 알림은 프로필의 준비 패스 카드에서 연다(메뉴 줄 없음)
        let reminders = app.buttons["pass.reminder"]
        for _ in 0..<5 { if reminders.waitForExistence(timeout: 2), reminders.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(reminders.isHittable); reminders.tap()
        XCTAssertTrue(app.buttons["reminder.lead.3"].waitForExistence(timeout: 5))
        app.buttons["reminder.lead.3"].tap()
        capture(app, "parity-reminders")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "저장했어요")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["reminder.back"].tap()
        XCTAssertTrue(app.buttons["pass.reminder"].waitForExistence(timeout: 5))
    }
    func testCreatePlanShowsBloomBeforeReturning() {
        let app = launch(); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.home"].exists); XCTAssertTrue(app.buttons["tab.add"].isSelected)
        capture(app, "review-create-start"); title.tap(); title.typeText("스튜디오 계약")
        let category = app.buttons["스튜디오"].firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 5)); category.tap()
        let cash = app.buttons["현금"]
        for _ in 0..<3 { if cash.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(cash.isHittable); cash.tap()
        XCTAssertTrue(app.buttons["addplan.save"].isEnabled); capture(app, "review-create-ready"); app.buttons["addplan.save"].tap()
        XCTAssertTrue(app.staticTexts["플랜이 등록되었어요"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["bloom.close"].exists)
        capture(app, "parity-bloom-created")
        app.buttons["bloom.close"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 5))
        // 꽃을 닫으면 플랜 추가도 빠지고 누른 화면(홈)으로 — 홈 탭이 다시 켜진다
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.textFields["addplan.title"])
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["tab.home"].isSelected)
    }
    /// 막 가입해 방이 아직 없는 사람도 플랜을 만든다 — 개인 일정으로 저장(Android `targetRoomAsync`, 2026-10-19 심사용 새 계정에서 막혔다)
    func testCreatePlanWithoutRoomSavesPersonally() {
        let app = launch(["-WPNoRoom"]); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("스튜디오 계약")
        let category = app.buttons["스튜디오"].firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 5)); category.tap()
        let cash = app.buttons["현금"]
        for _ in 0..<3 { if cash.isHittable { break }; app.swipeUp() }
        cash.tap()
        app.buttons["addplan.save"].tap()
        XCTAssertTrue(app.staticTexts["플랜이 등록되었어요"].waitForExistence(timeout: 10), "방이 없어도 저장돼야 한다")
        XCTAssertFalse(app.staticTexts["플랜을 불러오지 못했어요. 화면을 다시 열어 주세요."].exists)
    }
    func testOnboardingPermissionsCanBeSkipped() {
        let app = launch(["-WPForceOnboarding"])
        let next = app.buttons["setting.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10)); capture(app, "review-onboarding-date"); next.tap()
        let budget = app.textFields["setting.budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5)); capture(app, "review-onboarding-budget"); budget.tap(); budget.typeText("5000"); next.tap()
        let name = app.textFields["setting.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); capture(app, "review-onboarding-name"); name.tap(); name.typeText("지수"); capture(app, "review-onboarding-name-filled"); next.tap()
        let agree = app.buttons["setting.agreeAll"]
        XCTAssertTrue(agree.waitForExistence(timeout: 10)); capture(app, "review-onboarding-terms"); agree.tap(); capture(app, "review-onboarding-terms-agreed")
        let submit = app.buttons["setting.submit"]
        for _ in 0..<3 { if submit.isHittable { break }; app.swipeUp() }
        submit.tap()
        let permissionNext = app.buttons["setting.permissions.next"]
        XCTAssertTrue(permissionNext.waitForExistence(timeout: 10))
        capture(app, "parity-onboarding-permissions")
        let later = app.buttons["setting.permissions.later"]
        if later.exists { later.tap() } else { permissionNext.tap() }
        XCTAssertTrue(app.buttons["setting.inviteLater"].waitForExistence(timeout: 5)); capture(app, "review-onboarding-invite")
        app.buttons["setting.inviteLater"].tap()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10))
    }
    func testEditAndDeletePlanShowBloom() {
        let app = launch(["-WPPassEnabled"])
        let plan = app.staticTexts["드레스 1차 피팅"].firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        for _ in 0..<6 { if plan.isHittable { break }; app.swipeUp() }
        plan.tap()
        capture(app, "review-detail-top")
        let edit = app.buttons["수정하기"]
        for _ in 0..<8 { if edit.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(edit.isHittable)
        // Attach/delete belong in the editor; details only allow document viewing.
        XCTAssertFalse(app.buttons["파일 첨부"].exists)
        capture(app, "review-detail-actions")
        edit.tap()
        XCTAssertTrue(app.textFields["addplan.title"].waitForExistence(timeout: 5))
        // 수정하기도 플랜 추가 화면이라 탭바가 남는다(Android ADD_PLAN)
        XCTAssertTrue(app.buttons["tab.add"].isSelected)
        capture(app, "review-edit-top")
        let save = app.buttons["addplan.save"]
        for _ in 0..<12 { if save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.isEnabled); capture(app, "review-edit-ready"); save.tap()
        XCTAssertTrue(app.staticTexts["플랜이 수정되었어요"].waitForExistence(timeout: 10))
        capture(app, "parity-bloom-updated"); app.buttons["bloom.close"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.textFields["addplan.title"])
        waitForExpectations(timeout: 5)
        let delete = app.buttons["detail.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        for _ in 0..<8 { if delete.isHittable { break }; app.swipeUp() }
        delete.tap()
        XCTAssertTrue(app.staticTexts["이 플랜을 삭제할까요?"].waitForExistence(timeout: 5))
        capture(app, "review-delete-confirm")
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
        // Android 처럼 아이콘 줄 아래에 제목이 따로 섭니다
        XCTAssertGreaterThan(heading.frame.minY, close.frame.maxY - 4, "Title sits below the icon row")
        XCTAssertFalse(app.keyboards.element.exists, "키보드는 칸을 직접 눌렀을 때만")
        email.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        capture(app, "email-compact-initial")
        email.typeText("invalid")
        app.buttons["email.submit"].tap()
        XCTAssertTrue(app.staticTexts["email.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["email.submit"].isHittable)
        capture(app, "email-compact-validation")
        email.tap(); email.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "member@example.com")
        app.buttons["email.submit"].tap()
        let password = app.secureTextFields["email.password"]
        // Android port-password-error 와 같은 상태로 찍는다 — 오류 문구, 키보드 내림.
        // app.screenshot() 은 키보드 창을 담지 않아, 키보드가 떠 있으면 시트만 그 높이만큼 비어 솟아 보인다.
        XCTAssertTrue(password.waitForExistence(timeout: 5)); password.tap(); password.typeText("wrong-password\n")
        XCTAssertTrue(app.staticTexts["email.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.keyboards.element.exists)
        capture(app, "parity-email-password")
        password.tap(); password.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 14) + "test-password")
        XCTAssertTrue(app.buttons["email.submit"].isHittable)
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
        // 시뮬레이터 캡처에는 키보드가 찍히지 않아 빈 시트로 보입니다 — 빈 곳을 눌러 내리고 찍습니다
        app.staticTexts["email.title"].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 5), "빈 곳을 누르면 키보드가 내려간다")
        XCTAssertEqual((password.value as? String)?.count, "new-password".count, "가린 칸에도 값이 들어 있다")
        capture(app, "email-compact-signup")
        app.buttons["비밀번호 보기"].tap()
        XCTAssertTrue(app.textFields["email.password"].waitForExistence(timeout: 3))
        capture(app, "email-compact-signup-shown")
        app.buttons["비밀번호 가리기"].tap()
        app.buttons["email.close"].tap()
        app.buttons["auth.email"].tap()
        XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("member@example.com")
        app.buttons["email.submit"].tap()
        let forgot = app.buttons["비밀번호를 잊으셨나요?"]
        XCTAssertTrue(forgot.waitForExistence(timeout: 5)); forgot.tap()
        XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("123456")
        password.tap(); password.typeText("updated-password")
        XCTAssertTrue(app.buttons["email.submit"].isHittable)
        XCTAssertTrue(app.keyboards.element.exists)
        // 시뮬레이터 캡처에는 키보드가 찍히지 않아 그 자리가 빈 시트로 보입니다 — 빈 곳을 눌러 내리고 찍습니다
        app.staticTexts["email.title"].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 5), "빈 곳을 누르면 키보드가 내려간다")
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
        XCTAssertTrue(app.buttons["공개하러 가기"].waitForExistence(timeout: 10))
        capture(app, "parity-invitation-saved")
        app.buttons["공개하러 가기"].tap()
        XCTAssertTrue(app.buttons["청첩장 고치기"].waitForExistence(timeout: 10))
        for _ in 0..<5 { if app.buttons["공개하고 링크 받기"].isHittable { break }; app.swipeUp() }
        app.buttons["공개하고 링크 받기"].tap()
        XCTAssertTrue(app.buttons["invitation.address"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["invitation.shareNote"].waitForExistence(timeout: 5))
        capture(app, "parity-invitation-published")
        // 안드로이드 studio-mine-published-share 와 같은 자리 — 주소·QR 과 공개 안내 줄이 함께 보이게
        app.swipeUp(velocity: .slow)
        capture(app, "parity-invitation-share-note")
    }
}
