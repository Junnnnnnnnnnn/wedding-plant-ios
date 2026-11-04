import XCTest

/// 웹 초대 페이지의 `웨딩 플랜트 앱으로 열기` 가 기대는 길 — **시스템이 연 `weddingplant://share/…` 주소**
/// (웹 레포 `docs/ios-handoff-2026-11-04.md` 1번).
///
/// `-WPShareCode` 로 띄우는 기존 장면(ScreenshotTests)은 `.onOpenURL` 을 건너뛴다. 여기서는 앱이 떠 있는 채로
/// 시스템에 주소를 열게 해 `.onOpenURL` → `AppEnvironment.handle(url:)` → `ShareLink.invite` → 참여 화면까지를
/// 실제 경로로 본다. Universal Link(`https://weddingplant.app/share/…`)도 같은 `.onOpenURL` 로 들어온다.
///
/// **데모 모드는 카카오 SDK 를 켜지 않는다** — 그래서 이 테스트가 "SDK 가 켜지기 전에 온 주소" 를 늘 재현한다.
/// 예전에는 여기서 `KakaoSDK.redirectUri()` 의 `try!` 로 앱이 죽었다(`SocialLoginService.handleKakaoOpenURL`).
///
/// 시뮬레이터에 같은 스킴을 가진 다른 앱(옛 번들 ID `com.zipshowkorea.weddingplant` 개발 빌드)이 깔려 있으면
/// 시스템이 그쪽으로 보낸다 — 실패하면 그 앱부터 지운다.
final class InviteLinkUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(loggedOut: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode"]
        if loggedOut { app.launchArguments.append("-WPLoggedOut") }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
        return app
    }

    /// 시스템이 주소를 열고, "'웨딩 플랜트'에서 열겠습니까?" 가 뜨면 `열기` 를 누른다.
    private func openFromSystem(_ link: String) {
        XCUIDevice.shared.system.open(URL(string: link)!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["열기"].firstMatch
        if open.waitForExistence(timeout: 5) { open.tap() }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 로그인한 사람: 배우자 초대 링크 → 수락 확인창(누르기 전에는 참여하지 않는다).
    func test_배우자_초대_스킴이_참여_확인창을_연다() {
        let app = launch(loggedOut: false)
        openFromSystem("weddingplant://share/DEMO-SHARE?as=spouse")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "초대 주소가 이 앱으로 오지 않았다")
        // 참여 화면 바깥의 `share.screen` 식별자가 안쪽 단추의 식별자를 덮어 글자로 찾는다.
        XCTAssertTrue(app.buttons["네, 같이 준비할게요"].waitForExistence(timeout: 15),
                      "배우자 초대인데 수락 확인창이 뜨지 않았다(?as=spouse 를 흘렸거나 .onOpenURL 이 안 탔다)")
        capture(app, "invite-scheme-spouse-confirm")
    }

    /// 로그인 안 한 사람: 같은 링크 → 로그인 안내(로그인하면 이 초대로 이어진다 — `pendingShareCode`).
    func test_비로그인이면_초대를_들고_로그인으로_안내한다() {
        let app = launch(loggedOut: true)
        openFromSystem("weddingplant://share/DEMO-SHARE?as=spouse")

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "초대 주소가 이 앱으로 오지 않았다")
        XCTAssertTrue(app.staticTexts["공유 플랜을 보려면 로그인해 주세요"].waitForExistence(timeout: 15),
                      "비로그인인데 초대 화면의 로그인 안내가 뜨지 않았다")
        capture(app, "invite-scheme-login-required")
    }
}
