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
        XCTAssertTrue(app.webViews.buttons["건너뛰기"].waitForExistence(timeout: 30), "웹 프로세스가 늦게 뜰 때가 있다")
        // 열기 동안 화면에 그려진 카드 폭을 계속 잰다 — 한 번만 재면 웹이 뜨는 속도에 따라 줄어든 뒤를 잴 때가 있다.
        // 가장 컸을 때 카드는 실제 화면 가운데에 크게 선다
        let card = app.webViews.buttons["준비 패스 카드"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let screen = app.frame
        var big: CGFloat = 0
        var bigMidY: CGFloat = 0
        let until = Date().addingTimeInterval(7)
        while Date() < until {
            let (width, midY) = drawnCard(in: app, band: card.frame)
            if width > big { big = width; bigMidY = midY }
            usleep(250_000)
        }
        XCTAssertEqual(card.frame.midX, screen.midX, accuracy: 2)
        XCTAssertGreaterThan(bigMidY, screen.height * 0.38, "카드가 화면 위쪽에 몰리지 않는다")
        XCTAssertGreaterThan(big, 180, "열기 카드는 크게")
        // 열기가 끝나면 문서 속 자리로 줄어든다
        sleep(3)
        let small = drawnCard(in: app, band: card.frame).width
        XCTAssertLessThan(small, big - 20, "열기가 끝나면 카드가 줄어든다")
        let web = app.webViews.firstMatch
        web.swipeUp(velocity: .slow); sleep(2)
        web.swipeDown(velocity: .slow); sleep(2)
    }

    /// 화면에 그려진 밝은 카드의 폭(포인트)과 그 세로 가운데 — 어두운 바탕 위 밝은 띠를 줄마다 재서 가장 넓은 폭.
    /// WKWebView 의 접근성 프레임은 CSS transform 배율을 따르지 않아(문서 속 자리 크기) 스크린샷으로 잰다.
    private func drawnCard(in app: XCUIApplication, band: CGRect) -> (width: CGFloat, midY: CGFloat) {
        guard let image = XCUIScreen.main.screenshot().image.cgImage,
              let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return (0, 0) }
        let scale = CGFloat(image.width) / app.frame.width
        let perPixel = image.bitsPerPixel / 8, row = image.bytesPerRow
        var best = 0
        var rows: [Int] = []
        // 카드 자리(접근성 프레임은 위치는 따라간다) 안의 줄만 — 아래 문서의 흰 패널을 카드로 세지 않게
        let top = max(0, Int(band.minY * scale)), bottom = min(image.height, Int(band.maxY * scale))
        for py in stride(from: top, to: max(top, bottom), by: Int(4 * scale)) {
            var run = 0, longest = 0
            for px in 0..<image.width {
                let i = py * row + px * perPixel
                let luma = (Int(bytes[i]) + Int(bytes[i + 1]) + Int(bytes[i + 2])) / 3
                if luma > 170 { run += 1; longest = max(longest, run) } else { run = 0 }
            }
            // 카드보다 넓은 밝은 줄(문서의 흰 패널 · 화면 끝까지)은 카드가 아니다
            if longest < image.width * 8 / 10, longest > Int(60 * scale) {
                if longest > best { best = longest }
                rows.append(py)
            }
        }
        let mid = rows.isEmpty ? 0 : CGFloat(rows.reduce(0, +)) / CGFloat(rows.count) / scale
        return (CGFloat(best) / scale, mid)
    }
}
