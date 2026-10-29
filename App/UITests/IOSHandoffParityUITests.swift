import XCTest

/// iOS 수정 요청서(2026-10-28) 8건을 Android 8c1068b 와 같은 장면으로 찍는다 — Android 쪽 캡처는
/// `wedding-plant-android/docs/test-reports/2026-10-28-ios-parity/screenshots/`.
final class IOSHandoffParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + extra
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String, wait: UInt32 = 1) {
        sleep(wait)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    /// 한 줄(y)에서 버튼의 분홍(#edb0d0 언저리) 픽셀이 시작하고 끝나는 x(포인트)
    static func pinkSpan(_ image: UIImage, y: CGFloat) -> (CGFloat, CGFloat) {
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return (0, 0) }
        let scale = CGFloat(cg.width) / image.size.width, row = Int(y * scale), bpp = cg.bitsPerPixel / 8, stride = cg.bytesPerRow
        var first = -1, last = -1
        for x in 0..<cg.width {
            let p = row * stride + x * bpp
            let (b, g, r) = (Int(bytes[p]), Int(bytes[p + 1]), Int(bytes[p + 2]))
            let pink = r > 200 && g > 150 && g < 200 && b > 180
            if pink { if first < 0 { first = x }; last = x }
        }
        return (CGFloat(first) / scale, CGFloat(last) / scale)
    }

    private func kstDay(offset: Int) -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = calendar.date(byAdding: .day, value: offset, to: Date())!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// 02 — 일정 탭은 보드로 시작하고 전환에 아이콘이 붙는다
    func test02BoardIsDefaultWithIcons() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.schedule"].waitForExistence(timeout: 10)); app.buttons["tab.schedule"].tap()
        let board = app.buttons["calendar.view.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        XCTAssertTrue(board.isSelected, "처음 들어오면 보드")
        XCTAssertEqual(board.label, "🗂️ 보드")
        XCTAssertEqual(app.buttons["calendar.view.calendar"].label, "📅 달력")
        capture(app, "02-board-default", wait: 2)
        capture(app, "02-board-default-later", wait: 4)
        app.buttons["calendar.view.calendar"].tap()
        XCTAssertTrue(app.buttons["calendar.view.calendar"].isSelected)
        capture(app, "02-calendar")
    }

    /// 07 — 지난 날짜의 새 플랜: 결제 칸이 켜진 채 잠기고 안내가 붙는다 → 저장하면 완료 카드
    func test07PastNewPlanIsPaidAndLocked() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.schedule"].waitForExistence(timeout: 10)); app.buttons["tab.schedule"].tap()
        XCTAssertTrue(app.buttons["calendar.view.calendar"].waitForExistence(timeout: 5)); app.buttons["calendar.view.calendar"].tap()
        let yesterday = app.buttons["calendar.day.\(kstDay(offset: -1))"]
        if !yesterday.waitForExistence(timeout: 3) { app.buttons["calendar.prev"].tap() }
        XCTAssertTrue(yesterday.waitForExistence(timeout: 5)); yesterday.tap()
        app.buttons["calendar.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("드레스 투어\n")
        let chip = app.buttons["addplan.suggest.드레스"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5)); chip.tap()
        XCTAssertTrue(app.buttons["카드"].waitForExistence(timeout: 5)); app.buttons["카드"].tap()
        let notice = app.staticTexts["addplan.pastNotice"]
        for _ in 0..<5 where !(notice.exists && notice.isHittable) { app.swipeUp() }
        XCTAssertTrue(notice.exists, "지난 날짜 안내")
        let paid = app.buttons["addplan.paid"]
        paid.tap() // 잠겨 있어 꺼지지 않는다
        XCTAssertTrue(notice.exists)
        capture(app, "07-past-plan-locked")
        app.buttons["addplan.save"].tap()
        XCTAssertTrue(app.buttons["bloom.close"].waitForExistence(timeout: 10), "생성 → 완료 처리 → 완료 카드")
        capture(app, "07-past-plan-saved")
    }

    /// 05 — 예산의 엑셀 버튼에 패스 회전 테두리(패스 없음 → 소개, 있음 → 내려받기 갈래는 그대로)
    func test05ExportButtonHasRotatingBorder() {
        let app = launch()
        XCTAssertTrue(app.buttons["main.budget"].waitForExistence(timeout: 10)); app.buttons["main.budget"].tap()
        let export = app.buttons["budget.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        for _ in 0..<4 where !export.isHittable { app.swipeUp() }
        capture(app, "05-export-border-0", wait: 1)
        capture(app, "05-export-border-1", wait: 2)
    }

    /// 03 · 04 — 패스 소개 마지막 구역이 화면 가운데에 서고, 요금제에 고정 원화 부가 문구가 없다
    func test03FinalSectionCenteredAnd04NoFixedWonCopy() {
        let app = launch()
        XCTAssertTrue(app.buttons["main.budget"].waitForExistence(timeout: 10)); app.buttons["main.budget"].tap()
        let export = app.buttons["budget.export"]
        for _ in 0..<4 where !(export.exists && export.isHittable) { app.swipeUp() }
        export.tap()
        let skip = app.webViews.buttons["건너뛰기"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10)); skip.tap()
        let web = app.webViews.firstMatch
        let primary = app.webViews.links["준비 패스 알아보기"]
        for _ in 0..<20 { if primary.exists && primary.isHittable && primary.frame.maxY < app.frame.height - 60 { break }; web.swipeUp() }
        XCTAssertTrue(primary.isHittable)
        sleep(2)
        let title = app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS '하나의 패스로'")).firstMatch
        let mid = app.frame.midX
        _ = (title, mid)
        // 웹뷰의 접근성 프레임은 그려진 자리와 어긋나(같은 화면에서 ±20pt) 위치는 캡처의 픽셀로 본다 — 버튼 분홍 면의 좌우 끝
        let image = app.screenshot().image
        let (left, right) = Self.pinkSpan(image, y: primary.frame.midY)
        XCTAssertGreaterThan(right, left)
        XCTAssertEqual((left + right) / 2, image.size.width / 2, accuracy: 3, "버튼 분홍 면의 가운데 = 화면 가운데")
        capture(app, "03-final-centered")
        let plansLink = app.webViews.links["요금제 보기"]
        XCTAssertTrue(plansLink.exists); plansLink.tap()
        XCTAssertTrue(app.buttons["pass.buy"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["365일 동안"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '원꼴'")).firstMatch.exists)
        capture(app, "04-plans-no-fixed-won")
    }

    /// 06 · 01 — 피드 `+` 옆 작성 가능 개수, 후기 상자 빈 곳을 눌러도 키보드
    func test06BadgeAnd01ReviewBoxFocus() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        let open = app.buttons["feed.post.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        let labelled = NSPredicate(format: "label == '내 후기 올리기, 작성 가능한 후기 2개'")
        expectation(for: labelled, evaluatedWith: open); waitForExpectations(timeout: 10)
        capture(app, "06-postable-badge")
        open.tap()
        XCTAssertTrue(app.staticTexts["견적 후기 올리기"].waitForExistence(timeout: 5))
        let schedule = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'feed.post.schedule.'")).firstMatch
        XCTAssertTrue(schedule.waitForExistence(timeout: 5)); schedule.tap()
        let body = app.textViews["feed.post.body"].exists ? app.textViews["feed.post.body"] : app.textFields["feed.post.body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        sleep(1)
        // 칸(글 한 줄) 아래의 빈 곳 — 상자 안쪽 아래 여백
        // 상자가 바닥 `후기 올리기` 줄 위로 다 올라오게 시트 안을 굴린다(줄 밑을 누르면 그 줄이 눌린다)
        let submit = app.buttons["feed.post.submit"]
        for _ in 0..<4 where body.frame.maxY + 60 > submit.frame.minY {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        let frame = body.frame
        // 글 한 줄짜리 칸 바로 아래 — 상자(최소 84) 안의 빈 곳
        let below = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.maxY + 22))
        capture(app, "01-before-blank-tap")
        below.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "빈 곳을 눌러도 키보드가 올라온다")
        capture(app, "01-keyboard-open")
        body.typeText("좋았어요")
        // 키보드를 내리고(바깥 누름) 다시 빈 곳
        app.staticTexts["견적 후기 올리기"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.keyboards.firstMatch); waitForExpectations(timeout: 5)
        below.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "다시 눌러도 올라온다")
        capture(app, "01-keyboard-reopened")
    }
}
