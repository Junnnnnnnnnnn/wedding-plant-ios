import XCTest

/// 새 플랜 등록의 서류 칸(Android `PendingDocsShotTest`, 2026-10-16) — 패스가 없으면 무지개 테두리의 잠긴 칸,
/// 있으면 저장 전에 담아 두고 저장할 때 그 일정에 올린다. 앨범 · 파일 앱은 앱 밖이라 `-WPPendingDocsSample` 로 담는다.
final class PendingDocsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openForm(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["tab.add"].waitForExistence(timeout: 10)); app.buttons["tab.add"].tap()
        let title = app.textFields["addplan.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("웨딩홀 계약\n")
        app.buttons["addplan.category"].tap()
        let tile = app.buttons.matching(identifier: "category.tile.웨딩홀").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5)); tile.tap()
        app.buttons["category.confirm"].tap()
        let card = app.buttons["카드"]
        XCTAssertTrue(card.waitForExistence(timeout: 5)); card.tap()
        return app
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 { if element.exists && element.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testLockedCardOpensPassIntro() {
        let app = openForm([])
        let locked = app.descendants(matching: .any)["addplan.docs.locked"].firstMatch
        scrollTo(locked, in: app)
        XCTAssertTrue(app.staticTexts["계약서"].exists && app.staticTexts["영수증"].exists, "잠긴 칸은 설명 대신 예시 타일")
        capture(app, "pending-docs-locked")
        locked.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pass.intro"].waitForExistence(timeout: 5), "잠긴 칸을 누르면 준비 패스 소개")
    }

    func testStagedDocsUploadWhenSaving() {
        let app = openForm(["-WPPassEnabled", "-WPPendingDocsSample"])
        let photo = app.buttons["addplan.docs.photo"]
        scrollTo(photo, in: app)
        XCTAssertTrue(app.staticTexts["서류 2"].exists, "담아 둔 두 장이 머리에 센다")
        XCTAssertTrue(app.buttons["영수증.jpg 빼기"].exists)
        capture(app, "pending-docs-staged")
        app.buttons["addplan.save"].tap()
        let progress = expectation(for: NSPredicate(format: "label BEGINSWITH '서류 올리는 중'"), evaluatedWith: app.buttons["addplan.save"])
        wait(for: [progress], timeout: 5)
        capture(app, "pending-docs-uploading")
        XCTAssertFalse(app.buttons["영수증.jpg 빼기"].exists, "올리는 중에는 뺄 수 없다")
        XCTAssertTrue(app.buttons["bloom.close"].waitForExistence(timeout: 10), "다 올리면 완료 카드")
        XCTAssertFalse(app.descendants(matching: .any)["app.toast"].exists, "다 올렸으면 알림이 없다")
    }

    func testStorageFullStopsAndSaysWhy() {
        let app = openForm(["-WPPassEnabled", "-WPPendingDocsSample", "-WPDocsStorageFull"])
        scrollTo(app.buttons["addplan.docs.photo"], in: app)
        app.buttons["addplan.save"].tap()
        let toast = app.descendants(matching: .any)["app.toast"].firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 10), "못 올린 서류는 알린다")
        XCTAssertEqual(toast.label, "저장 공간이 가득 찼어요.", "멈춘 까닭(용량)을 서버 문장 그대로")
        capture(app, "pending-docs-storage-full")
        XCTAssertTrue(app.buttons["bloom.close"].waitForExistence(timeout: 5), "플랜은 저장됐다")
    }
}
