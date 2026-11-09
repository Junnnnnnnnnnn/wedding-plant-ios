import XCTest

/// 실제 FCM/APNs 수신과 simctl 주입 수신을 별도 테스트로 검증한다.
final class NativeSchedulePushUITests: XCTestCase {
    func testCloudPush() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WP_EXTERNAL_PUSH_REVIEW"] == "1", "외부 발송 스크립트와 함께 실행: TEST_RUNNER_WP_EXTERNAL_PUSH_REVIEW=1")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPCloudPushReview", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        let spring = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = spring.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "허용", "Allow")).firstMatch
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        XCTAssertTrue(app.buttons["main.inbox"].waitForExistence(timeout: 20))
        let banner = spring.staticTexts["QA-CLOUD ios 운영 서버 푸시 수신 검증"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 100))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "features-cloud-fcm-received"; shot.lifetime = .keepAlways; add(shot)
        banner.tap()
        XCTAssertTrue(app.buttons["calendar.add"].waitForExistence(timeout: 10))
    }

    func testDeletedScheduleBannerAndListRoute() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WP_EXTERNAL_PUSH_REVIEW"] == "1", "외부 simctl 주입 스크립트와 함께 실행: TEST_RUNNER_WP_EXTERNAL_PUSH_REVIEW=1")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPNativePushReview", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        let spring = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = spring.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "허용", "Allow")).firstMatch
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        XCTAssertTrue(app.buttons["main.inbox"].waitForExistence(timeout: 15))
        let banner = spring.staticTexts["QA-일정알림검증: 현우님이 일정을 삭제했어요."].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 45))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "features-native-schedule-notification"; shot.lifetime = .keepAlways; add(shot)
        banner.tap()
        XCTAssertTrue(app.buttons["calendar.add"].waitForExistence(timeout: 10))
        let route = XCTAttachment(screenshot: app.screenshot())
        route.name = "features-native-schedule-route"; route.lifetime = .keepAlways; add(route)
    }
}
