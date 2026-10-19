import XCTest

/// 준비 패스 소개의 열기 장면을 실제 속도로 띄워 두는 테스트 — `xcrun simctl io <기기> recordVideo` 로 찍는다
/// (2026-10-19 사용자 "카드가 가운데 크게 보였다가 줄어들어야"). 손대지 않고 열기가 끝날 때까지 기다린 뒤 조금 굴린다.
final class PassOpeningRecordUITests: XCTestCase {
    func testHoldOpening() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        for _ in 0..<3 {
            app.buttons["main.profile"].tap()
            if app.buttons["user.pass"].waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.buttons["user.pass"].waitForExistence(timeout: 5))
        sleep(2)
        app.buttons["user.pass"].tap()
        XCTAssertTrue(app.webViews.buttons["건너뛰기"].waitForExistence(timeout: 10))
        // 열기 한가운데(카드가 나온 뒤) — 카드는 실제 화면 가운데에 크게 선다
        sleep(4)
        let card = app.webViews.buttons["준비 패스 카드"]
        XCTAssertTrue(card.exists)
        let screen = app.frame
        XCTAssertEqual(card.frame.midX, screen.midX, accuracy: 2)
        XCTAssertGreaterThan(card.frame.midY, screen.height * 0.38, "카드가 화면 위쪽에 몰리지 않는다")
        XCTAssertGreaterThan(card.frame.width, 180, "열기 카드는 크게")
        let big = card.frame.width
        // 열기가 끝나면 문서 속 자리로 줄어든다
        sleep(5)
        XCTAssertLessThan(card.frame.width, big - 20, "열기가 끝나면 카드가 줄어든다")
        let web = app.webViews.firstMatch
        web.swipeUp(velocity: .slow); sleep(2)
        web.swipeDown(velocity: .slow); sleep(2)
    }
}
