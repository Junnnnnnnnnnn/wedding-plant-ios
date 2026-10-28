import XCTest

/// 내보내기 시트에서 덜어낸 글 — Android `CalendarExportShotTest`(7622e73 · 웹 39406e5, 2026-10-28). 머리 글 · 파일 형식 아래 설명 ·
/// 미리보기 아래 두 줄 · 아래 둘째 줄이 다시 나오지 않고, 제목 아래 설명과 아래 요약 첫 줄은 남는다.
final class ExportSheetParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private let removed = [
        "KEEP OUR PLANS",
        "첫 장은 요약, 둘째 장부터 고쳐 쓰는 표",
        "공유하고 인쇄하기 좋은 A4 가로 타임라인",
        "미리보기는 일부만 보여 줘요",
        "내 일정 다운로드는 준비 패스에 포함돼요.",
        "실제 내 일정은 포함되지 않아요.",
    ]

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    /// 어절 줄바꿈 글자(U+2060)를 빼고 보이는 글자로 찾는다 — 그냥 찾으면 "없다" 가 헛통과한다(Android `onNodeWithVisibleText`)
    private func visibleTexts(_ app: XCUIApplication) -> [String] {
        app.staticTexts.allElementsBoundByIndex.map { $0.label.replacingOccurrences(of: "\u{2060}", with: "") }
    }

    private func assertRemovedGone(_ app: XCUIApplication) {
        // 시트 본문은 지연 목록이 아니라 화면 밖 글도 접근성 트리에 있다 — 굴리지 않고 본다(맨 위에서 끌면 시트가 닫힌다)
        let seen = visibleTexts(app)
        XCTAssertGreaterThan(seen.count, 10)
        for text in removed { XCTAssertFalse(seen.contains { $0.contains(text) }, "\(text) 가 남아 있다") }
    }

    private func open(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["main.profile"].waitForExistence(timeout: 10))
        app.buttons["main.profile"].tap()
        let export = app.buttons["엑셀 받기"]
        for _ in 0..<6 { if export.waitForExistence(timeout: 2), export.isHittable { break }; app.swipeUp() }
        export.tap()
        XCTAssertTrue(app.buttons["export.save"].waitForExistence(timeout: 10))
        sleep(1)
    }

    func testXlsxAndPdfSampleHaveNoRemovedCopy() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPPassEnabled", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        open(app)
        XCTAssertTrue(app.staticTexts["우리의 준비, 한 장에 담기"].exists)
        XCTAssertTrue(visibleTexts(app).contains { $0.contains("마음에 드는 양식을 고르고") }, "제목 아래 설명은 남는다")
        XCTAssertTrue(visibleTexts(app).contains { $0.contains("개 일정 · ") }, "아래 요약 첫 줄은 남는다")
        capture(app, "export-xlsx")
        assertRemovedGone(app)

        app.buttons["PDF"].tap()
        let sample = app.buttons["예시 데이터"]
        for _ in 0..<4 { if sample.isHittable { break }; app.scrollViews["export.scroll"].swipeUp() }
        sample.tap()
        XCTAssertTrue(visibleTexts(app).contains("예시 데이터로 양식을 확인해 보세요"))
        for _ in 0..<4 where !app.buttons["PDF"].isHittable { app.scrollViews["export.scroll"].swipeDown(velocity: .slow) }
        sleep(1)
        capture(app, "export-pdf-sample")
        assertRemovedGone(app)
    }
}
