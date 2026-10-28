import XCTest

/// 시뮬레이터에서 직접 — 사진 앨범에서 고른 사진이 WebP 로 올라가 표지에 서는지(데모 서버는 `image/webp` 가 아니면 거절한다),
/// 홈의 `새 축하 N` 이 청첩장 칸에서 본 수와 비교되는지. Android c857963 · 1e62d83.
final class InvitationPhotoAndWishesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPPassEnabled", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + extra
        app.launch()
        return app
    }

    func testCoverPhotoFromLibraryUploadsAsWebp() {
        let app = launch(["-WPExistingInvitation"])
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10)); app.buttons["tab.explore"].tap()
        app.buttons["explore.invitation"].tap()
        let edit = app.buttons["청첩장 고치기"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        for _ in 0..<5 { if edit.isHittable { break }; app.swipeUp() }
        edit.tap()
        let cover = app.buttons["invitation.coverPhoto"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        cover.tap()
        // 사진 선택기 — 다 뜰 때까지 기다린 뒤 맨 앞(가장 최근에 넣은 회전 사진)
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 20), "사진 선택기가 뜬다")
        capture(app, "inv-photo-picker")
        sleep(2)
        // 선택기는 다른 프로세스라 칸이 hittable 로 읽히지 않는다 — 자리를 직접 누른다
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let add = app.buttons["추가"]
        if add.waitForExistence(timeout: 2) { add.tap() }
        // 올리는 동안 상태 → 끝나면 저장하지 않은 변경, 오류 없음
        XCTAssertTrue(app.staticTexts["저장하지 않은 변경이 있어요"].waitForExistence(timeout: 20), "사진이 초안에 들어온다")
        XCTAssertFalse(app.staticTexts["invitation.error"].exists, "데모 서버가 WebP 를 받았다(JPEG 면 'WebP 사진만 받아요')")
        capture(app, "inv-photo-cover-uploaded")
        app.buttons["invitation.save"].tap()
        XCTAssertTrue(app.buttons["공개하러 가기"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["invitation.error"].exists)
        capture(app, "inv-photo-saved")
    }

    func testHomeFreshWishesCountsFromWhatTheStudioShowed() {
        // 처음 — 이 기기에서 본 적이 없으면 지금 수(3)가 기준, 새 축하 0
        var app = launch(["-WPInvitationPublished", "-WPInvitationGuestsTotal", "3", "-WPResetInvitationSeen"])
        XCTAssertTrue(app.staticTexts["청첩장 공개 중 · 하객 3명"].waitForExistence(timeout: 15), "처음에는 지어내지 않는다")
        capture(app, "home-wishes-first")
        app.terminate()

        // 하객이 둘 늘었다 — 기준 3 과 비교해 새 축하 2
        app = launch(["-WPInvitationPublished", "-WPInvitationGuestsTotal", "5"])
        XCTAssertTrue(app.staticTexts["청첩장 공개 중 · 새 축하 2"].waitForExistence(timeout: 15))
        capture(app, "home-wishes-fresh")
        sleep(5)
        capture(app, "home-wishes-fresh-later")

        // 청첩장 칸에서 보고 돌아오면 줄어든다 — 카드는 둘러보기 탭의 청첩장 칸으로 옮기므로(Android `Routes.feed(EXPLORE_INVITATION)`)
        // 돌아오는 길은 뒤로가기가 아니라 홈 탭이다
        app.buttons["main.invitationGarden"].tap()
        XCTAssertTrue(app.buttons["청첩장 고치기"].waitForExistence(timeout: 10))
        sleep(2)
        app.buttons["tab.home"].tap()
        XCTAssertTrue(app.staticTexts["청첩장 공개 중 · 하객 5명"].waitForExistence(timeout: 10), "칸에서 본 수가 기준이 된다")
        capture(app, "home-wishes-after-studio")
    }
}
