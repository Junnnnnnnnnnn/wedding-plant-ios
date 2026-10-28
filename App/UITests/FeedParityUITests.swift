import XCTest

/// Android v40 · v41(4a785da · 55d40d0) — 내 후기는 담기 · 투표 대신 수정하기, 고치기 · 내리기, 후기 사진, 업체 고르기,
/// 공유하기, 올라온 후기에 있는 카테고리만 칩. 안드로이드 `FeedParityTest` · `FeedCategoriesTest` 와 같은 데이터
/// (`-WPFeedParity`)로 같은 장면을 찍어 1:1 로 맞춘다.
final class FeedParityUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode", "-WPFeedParity", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["tab.explore"].waitForExistence(timeout: 10))
        app.buttons["tab.explore"].tap()
        XCTAssertTrue(app.staticTexts["햇살 스튜디오"].waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    /// 시트 안에서 손가락 하나 길이만큼 올린다 — 시트 밖(딤)을 끌면 시트가 내려간다
    private func scrollSheet(_ app: XCUIApplication, until target: XCUIElement, max: Int = 6) {
        for _ in 0..<max {
            if target.exists && target.isHittable && target.frame.maxY < app.frame.height - 140 { return }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        }
    }

    func testOwnerCardOtherCardPhotosAndShare() {
        let app = launch()
        // 칩은 올라온 후기에 있는 것만, 많이 올라온 순(스튜디오 2 · 상견례 1) — 예전 마스터 목록의 칩(예식장 등)은 없다
        XCTAssertTrue(app.buttons["스튜디오"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["상견례"].exists)
        XCTAssertFalse(app.buttons["예식장"].exists)
        XCTAssertLessThan(app.buttons["스튜디오"].frame.minX, app.buttons["상견례"].frame.minX)
        // 내 후기 — 도움이 됐어요 N · 수정하기 · 공유하기만
        XCTAssertTrue(element(app, "feed.edit.720").exists)
        XCTAssertFalse(element(app, "feed.copy.720").exists, "내 후기에는 담기가 없다")
        XCTAssertTrue(element(app, "feed.helpfulCount").exists)
        XCTAssertTrue(element(app, "feed.share.720").exists)
        capture(app, "a1-feed-list-top")
        app.swipeUp()
        XCTAssertTrue(element(app, "feed.copy.721").waitForExistence(timeout: 3), "남의 후기는 그대로 담기")
        XCTAssertTrue(app.buttons["도움이 안 돼요"].exists)
        XCTAssertTrue(element(app, "feed.share.721").exists)
        capture(app, "a1b-feed-list-other")

        // 남의 후기 상세 — 사진 격자 · 투표 · 공유 · 담기
        app.staticTexts["라뮈에스튜디오"].firstMatch.tap()
        XCTAssertTrue(element(app, "feed.detail.copy").waitForExistence(timeout: 5))
        capture(app, "a5-detail-other-top")
        let share = element(app, "feed.share.721")
        // `isHittable` 은 바닥의 `내 플랜에 담기` 줄에 가린 것도 참이라(표본이 적어 금액 자가 빠지면 공유 줄이 그 밑에 걸린다)
        // 바닥 줄 위로 올라올 때까지 굴린다
        let copyBar = element(app, "feed.detail.copy")
        for _ in 0..<4 where !(share.exists && share.isHittable && share.frame.maxY < copyBar.frame.minY - 8) { app.swipeUp() }
        XCTAssertTrue(element(app, "feed.photo.2").exists)
        XCTAssertFalse(element(app, "feed.photo.3").exists)
        capture(app, "a6-detail-other-photos")
        // 공유하기 — 시스템 공유 시트에 웹 후기 주소
        share.tap()
        let sheet = app.otherElements["ActivityListView"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5) || app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 3))
        capture(app, "a7-share-sheet")
    }

    func testOwnerDetailPhotoViewer() {
        let app = launch()
        app.staticTexts["햇살 스튜디오"].firstMatch.tap()
        XCTAssertTrue(element(app, "feed.detail.edit").waitForExistence(timeout: 5), "내 후기 상세의 바닥은 후기 수정하기")
        XCTAssertFalse(element(app, "feed.detail.copy").exists)
        XCTAssertFalse(app.buttons["도움이 안 돼요"].exists, "내 후기에는 투표가 없다")
        let photo = element(app, "feed.photo.2")
        for _ in 0..<3 where !(photo.exists && photo.isHittable) { app.swipeUp() }
        photo.tap()
        let page = element(app, "feed.viewer.page")
        XCTAssertTrue(page.waitForExistence(timeout: 5))
        XCTAssertEqual(page.label, "2 / 3")
        XCTAssertFalse(app.buttons["내려받기"].exists, "남의 사진일 수 있어 내려받기는 없다")
        capture(app, "02-viewer")
        element(app, "feed.viewer.pager").swipeLeft()
        XCTAssertTrue(NSPredicate(format: "label == '3 / 3'").evaluate(with: page) || page.label == "3 / 3")
        app.buttons["feed.viewer.close"].tap()
        XCTAssertFalse(page.waitForExistence(timeout: 1))
    }

    /// Android `editPrefillSaveLockAndDelete404` — 같은 내 후기(키만 하나)
    func testEditPrefillSaveAndDelete() {
        let app = launch(["-WPFeedOnePhoto"])
        element(app, "feed.edit.720").tap()
        XCTAssertTrue(app.staticTexts["후기 고치기"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["스튜디오 · 햇살 스튜디오 · 120만원"].exists, "고칠 수 없는 값은 요약 줄에만")
        XCTAssertTrue(element(app, "feed.post.photo.1").exists)
        XCTAssertFalse(element(app, "feed.post.photo.2").exists)
        capture(app, "03-edit-prefill")
        app.buttons["feed.post.star.3"].tap()
        scrollSheet(app, until: app.buttons["금액을 가립니다"])
        capture(app, "03b-edit-options")
        scrollSheet(app, until: app.buttons["feed.post.delete"])
        app.buttons["feed.post.delete"].tap()
        XCTAssertTrue(app.staticTexts["이 후기를 내릴까요?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["되돌릴 수 없고 사진도 함께 지워져요."].exists)
        scrollSheet(app, until: app.buttons["feed.post.delete.confirm"])
        capture(app, "04-delete-confirm")
        app.buttons["feed.post.delete.cancel"].tap()
        app.buttons["feed.post.submit"].tap()
        XCTAssertFalse(app.staticTexts["후기 고치기"].waitForExistence(timeout: 1) && app.staticTexts["후기 고치기"].isHittable)
        // 서버 응답으로 카드가 바로 바뀐다(다시 받지 않음)
        XCTAssertTrue(app.otherElements["만족도 3점"].waitForExistence(timeout: 5) || app.staticTexts["만족도 3점"].exists
                      || app.descendants(matching: .any)["만족도 3점"].exists)

        // 상세에서 고치기 → 금액을 가리고 한 줄을 바꾼다
        app.staticTexts["햇살 스튜디오"].firstMatch.tap()
        XCTAssertTrue(element(app, "feed.detail.edit").waitForExistence(timeout: 5))
        capture(app, "05-detail-owner")
        element(app, "feed.detail.edit").tap()
        let field = app.textFields["feed.post.body"].exists ? app.textFields["feed.post.body"] : app.textViews["feed.post.body"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.press(forDuration: 1.2)
        if app.menuItems["전체 선택"].waitForExistence(timeout: 2) { app.menuItems["전체 선택"].tap() } else if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        field.typeText("서버에서 받은 수정 내용")
        app.swipeDown(velocity: .slow)
        scrollSheet(app, until: app.buttons["금액을 가립니다"])
        app.buttons["금액을 가립니다"].tap()
        app.buttons["feed.post.submit"].tap()
        XCTAssertTrue(app.staticTexts["서버에서 받은 수정 내용"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["금액 비공개"].exists)
        capture(app, "06-detail-saved")

        // 내리기 → 목록으로, 카드가 사라진다
        element(app, "feed.detail.edit").tap()
        XCTAssertTrue(app.staticTexts["후기 고치기"].waitForExistence(timeout: 5))
        scrollSheet(app, until: app.buttons["feed.post.delete"], max: 8)
        app.buttons["feed.post.delete"].tap()
        app.buttons["feed.post.delete.confirm"].tap()
        XCTAssertTrue(app.staticTexts["라뮈에스튜디오"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["햇살 스튜디오"].waitForExistence(timeout: 2), "내린 후기는 목록에서 빠진다")
        XCTAssertTrue(app.buttons["스튜디오"].exists, "라뮈에스튜디오가 남아 칩도 남는다")
    }

    /// Android `serverChipsRefreshForPostDeleteAndBothModerationPaths` — 고른 칩의 마지막 후기가 빠지면 칩은 끝에 남고,
    /// `전체` 로 돌아가면 사라진다(목록 신고 길).
    func testDeletedSelectionStaysUntilReturningToAll() {
        let app = launch()
        XCTAssertTrue(app.buttons["상견례"].waitForExistence(timeout: 5))
        capture(app, "c1-posted-categories")
        app.buttons["상견례"].tap()
        XCTAssertTrue(app.staticTexts["다정한 식탁"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["햇살 스튜디오"].exists)
        element(app, "moderation.menu").tap()
        element(app, "moderation.report").tap()
        element(app, "moderation.reason.SPAM").tap()
        element(app, "moderation.submit").tap()
        XCTAssertTrue(element(app, "moderation.done").waitForExistence(timeout: 5))
        element(app, "moderation.done").tap()
        XCTAssertFalse(app.staticTexts["다정한 식탁"].waitForExistence(timeout: 2), "가린 글은 그 자리에서 빠진다")
        // 서버 칩에서는 상견례가 빠졌지만 고른 채라 끝에 남는다
        sleep(1)
        XCTAssertTrue(app.buttons["상견례"].exists)
        XCTAssertGreaterThan(app.buttons["상견례"].frame.minX, app.buttons["스튜디오"].frame.minX)
        capture(app, "c2-deleted-selection-retained")
        app.buttons["전체"].tap()
        XCTAssertTrue(app.staticTexts["햇살 스튜디오"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["상견례"].waitForExistence(timeout: 1), "전체로 돌아가면 사라진다")
        capture(app, "c3-return-to-all")
    }

    func testNewPostSheetPlaceAutoMatchAndSearch() {
        let app = launch()
        let write = element(app, "feed.write")
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        write.tap()
        XCTAssertTrue(app.staticTexts["견적 후기 올리기"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["이름 없이 공개돼요. 로그인하지 않은 사람과 검색 결과에도 보일 수 있어요."].exists)
        element(app, "feed.post.schedule.11").tap()
        // 일정의 좌표와 맞는 결과를 저절로 고른다
        XCTAssertTrue(element(app, "feed.post.place.change").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["서울 강남구 도산대로 501"].exists)
        sleep(1)
        capture(app, "feed-new-post-top")
        capture(app, "a2-new-post-top")
        scrollSheet(app, until: element(app, "feed.post.photo.add"))
        XCTAssertTrue(app.staticTexts["사진 (선택 · 3장까지)"].exists)
        capture(app, "a3-new-post-photos")
        // 바꾸기 → 업체명으로 찾기
        for _ in 0..<3 where !element(app, "feed.post.place.change").isHittable {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        }
        element(app, "feed.post.place.change").tap()
        XCTAssertEqual(app.textFields["feed.post.place.keyword"].value as? String, "청담 드레스룸")
        element(app, "feed.post.place.search").tap()
        XCTAssertTrue(app.staticTexts["청담 드레스룸 2호점"].waitForExistence(timeout: 5))
        capture(app, "a4-place-search")
        app.staticTexts["청담 드레스룸 2호점"].tap()
        XCTAssertTrue(app.staticTexts["서울 강남구 압구정로 60"].waitForExistence(timeout: 3))
        app.buttons["feed.post.submit"].tap()
        XCTAssertFalse(app.staticTexts["견적 후기 올리기"].waitForExistence(timeout: 3) && app.staticTexts["견적 후기 올리기"].isHittable)
        // 올리면 새 카테고리(드레스)의 첫 후기라 칩이 바로 생긴다
        XCTAssertTrue(app.buttons["드레스"].waitForExistence(timeout: 5))
        capture(app, "a8-after-post")
    }

    /// Android `photoConflictRebasesAndKeepsUploadedKeyForRetry` 의 화면 쪽 — 다른 곳에서 사진이 바뀌면 지금 사진으로 다시
    /// 맞추고 한 번 더 누르게 한다.
    func testPhotoConflictRebases() {
        let app = launch(["-WPFeedConflict"])
        element(app, "feed.edit.720").tap()
        XCTAssertTrue(app.staticTexts["후기 고치기"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "feed.post.photo.3").exists)
        app.buttons["feed.post.photo.remove.1"].tap()
        XCTAssertFalse(element(app, "feed.post.photo.3").exists)
        app.buttons["feed.post.submit"].tap()
        let error = element(app, "feed.post.error")
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("지금 사진으로 다시 불러왔어요"))
        XCTAssertTrue(element(app, "feed.post.photo.1").exists)
        XCTAssertFalse(element(app, "feed.post.photo.2").exists, "서버의 지금 사진(하나)으로 다시 맞췄다")
        capture(app, "09-conflict-rebased")
        app.buttons["feed.post.submit"].tap()
        XCTAssertFalse(app.staticTexts["후기 고치기"].waitForExistence(timeout: 3) && app.staticTexts["후기 고치기"].isHittable)
    }
}
