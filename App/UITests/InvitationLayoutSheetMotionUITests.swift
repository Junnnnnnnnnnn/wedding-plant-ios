import XCTest

/// 구성 시트는 바닥 시트처럼 움직인다 — 2026-10-28 실기기 녹화(내리면 애니메이션 없이 뚝 사라짐). Android `AppBottomSheet` 와 같게
/// 손가락을 따라 내려가 닫히고, 조금만 끌다 놓으면 제자리로 돌아온다. 움직임은 `simctl io recordVideo` 로 함께 찍어 프레임으로 본다.
final class InvitationLayoutSheetMotionUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLayoutSheetFollowsFingerAndSlidesAway() {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPPassEnabled", "-WPExistingInvitation", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        app.buttons["explore.invitation"].tap()
        let edit = app.buttons["청첩장 고치기"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        for _ in 0..<5 { if edit.isHittable { break }; app.swipeUp() }
        edit.tap()
        let pill = app.buttons["구성"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        sleep(1)
        pill.tap()
        let cover = app.buttons["invitation.editCover"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        sleep(1)

        // 조금 끌다 놓으면 돌아온다
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        top.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22)), withVelocity: 300, thenHoldForDuration: 0.4)
        sleep(1)
        XCTAssertTrue(cover.isHittable, "조금 끌면 시트가 제자리로")

        // 끝까지 끌어 내리면 손을 따라 내려가 닫힌다
        top.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)), withVelocity: 600, thenHoldForDuration: 0)
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: cover)
        wait(for: [gone], timeout: 3)
        XCTAssertTrue(pill.waitForExistence(timeout: 2), "미리보기로 돌아온다")
        sleep(1)
    }
}
