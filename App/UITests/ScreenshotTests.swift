import XCTest

/// 화면을 자동으로 돌면서 스크린샷을 남긴다.
///
/// Windows 개발 환경에서는 시뮬레이터를 띄울 수 없으므로, CI 가 이 테스트를 돌려 만든
/// 스크린샷(과 워크플로가 별도로 녹화하는 동영상)이 화면을 눈으로 확인하는 수단이다.
/// 그래서 **단언(assert)으로 실패시키지 않는다** — 무엇이 나왔든 일단 찍어서 올린다.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    private func makeApp(
        forceOnboarding: Bool = false,
        loggedOut: Bool = false,
        shareCode: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WPDemoMode"]
        if forceOnboarding {
            app.launchArguments.append("-WPForceOnboarding")
        }
        if loggedOut {
            app.launchArguments.append("-WPLoggedOut")
        }
        if let shareCode {
            // 공유 링크(Universal Link)를 흉내 낸다.
            app.launchArguments += ["-WPShareCode", shareCode]
        }
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle(_ seconds: TimeInterval = 2.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    // MARK: - 랜딩 → 설정

    /// 웹과 동일한 6단계 플로우: 축하 → 날짜 → 예산 → 이름 → 환영 → 약관
    ///
    /// 두 앱을 따로 띄운다. 예전에는 한 번 띄워 랜딩의 "로그인 없이 둘러보기" 를
    /// 눌러 온보딩으로 넘어갔는데, **그 입구를 없앴다**(웹·안드로이드와 같음).
    /// 지금은 토큰 유무가 두 화면을 가른다.
    func test_01_랜딩과_설정_플로우() {
        // 로그인 문 — 토큰이 없을 때만 보인다.
        let door = makeApp(loggedOut: true)
        door.launch()
        _ = door.wait(for: .runningForeground, timeout: 30)
        settle()
        capture(door, "01-landing")
        door.terminate()

        // 온보딩 — 로그인은 됐지만 이름·날짜·예산이 덜 찬 사람.
        let app = makeApp(forceOnboarding: true)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)

        // 축하 단계는 3초 뒤 자동으로 날짜 단계로 넘어간다.
        settle(1.0)
        capture(app, "02-celebration")
        settle(3.0)
        capture(app, "03-date")

        let next = app.buttons["setting.next"]
        guard next.waitForExistence(timeout: 5) else { return }
        next.tap()
        settle(1.0)
        capture(app, "04-budget")

        let budgetField = app.textFields["setting.budget"]
        if budgetField.isHittable {
            budgetField.tap()
            budgetField.typeText("5000")
            settle(0.5)
        }
        if next.isHittable { next.tap() }
        settle(1.0)
        capture(app, "05-name")

        let nameField = app.textFields["setting.name"]
        if nameField.isHittable {
            nameField.tap()
            nameField.typeText("지수")
            settle(0.5)
            capture(app, "06-name-filled")
        }
        if next.isHittable { next.tap() }

        // 환영 단계는 2.5초 뒤 약관으로 자동 전환된다.
        settle(1.0)
        capture(app, "07-welcome")
        settle(2.5)
        capture(app, "08-terms")

        if app.buttons["setting.agreeAll"].isHittable {
            app.buttons["setting.agreeAll"].tap()
            settle(0.8)
            capture(app, "09-terms-agreed")
        }
    }

    // MARK: - 메인 탭들

    func test_02_메인_탭_전체() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        // 데모 전송 계층에 200ms 지연이 있으므로 데이터가 채워질 시간을 준다.
        settle(3.0)

        capture(app, "04-main")

        // 커스텀 하단 탭바 — 접근성 식별자로 찾는다.
        if app.buttons["tab.rooms"].waitForExistence(timeout: 10) {
            app.buttons["tab.rooms"].tap()
            settle(2.5)
            capture(app, "05-plan-list")
        }

        if app.buttons["tab.settings"].isHittable {
            app.buttons["tab.settings"].tap()
            settle(2.5)
            capture(app, "06-user")
        }

        // 피드는 이제 실제 화면이다 — 목록·상세는 `test_04c_피드` 가 따로 찍는다.

        if app.buttons["tab.home"].isHittable {
            app.buttons["tab.home"].tap()
            settle(1.5)
            capture(app, "08-main-again")
        }
    }

    // MARK: - 정렬 시트 · 일정 상세

    /// 새로 만든 화면들. 여기서 찍지 않으면 CI 아티팩트에 영영 안 나온다.
    func test_03_정렬시트와_일정상세() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        // 정렬 시트
        if app.buttons["main.sort"].waitForExistence(timeout: 10) {
            app.buttons["main.sort"].tap()
            settle(1.5)
            capture(app, "09-sort-sheet")

            // 다른 정렬을 골라 목록이 바뀌는지도 남긴다.
            if app.buttons["높은 가격순"].isHittable {
                app.buttons["높은 가격순"].tap()
                settle(2.5)
                capture(app, "10-sorted-by-price")
            } else {
                app.swipeDown()
                settle(1.0)
            }
        }

        // 일정 상세 — 목록 첫 카드를 누른다.
        let firstPlan = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "드레스")
        ).firstMatch
        if firstPlan.waitForExistence(timeout: 10) {
            firstPlan.tap()
            settle(3.0)
            capture(app, "11-schedule-detail")

            // 삭제 확인 다이얼로그 (취소가 왼쪽인지 눈으로 확인하기 위함)
            if app.buttons["detail.delete"].isHittable {
                app.buttons["detail.delete"].tap()
                settle(1.5)
                capture(app, "12-delete-confirm")
                if app.buttons["취소"].isHittable {
                    app.buttons["취소"].tap()
                    settle(1.0)
                }
            }

            if app.buttons["detail.back"].isHittable {
                app.buttons["detail.back"].tap()
                settle(1.5)
            }
        }
    }

    // MARK: - 일정 추가

    /// 웹처럼 입력에 따라 섹션이 하나씩 나타나는지 단계별로 남긴다.
    func test_04_일정_추가() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        guard app.buttons["main.add"].waitForExistence(timeout: 10) else { return }
        app.buttons["main.add"].tap()
        settle(2.0)
        capture(app, "13-addplan-empty")

        // 제목을 넣으면 카테고리 섹션이 나타난다.
        let title = app.textFields["addplan.title"]
        if title.waitForExistence(timeout: 5) {
            title.tap()
            title.typeText("드레스 본식 대여")
            settle(1.5)
            capture(app, "14-addplan-category-revealed")
        }

        // 카테고리 선택 모달
        if app.buttons["addplan.category"].isHittable {
            app.buttons["addplan.category"].tap()
            settle(1.5)
            capture(app, "15-category-modal")

            // 시트를 닫는다. 닫힘 애니메이션이 끝나야 아래 화면이 다시 눌린다.
            app.swipeDown()
            settle(2.0)
        }

        // 스크린샷용 테스트는 단언으로 실패시키지 않는다.
        // 눌리지 않는 요소를 tap 하면 XCTest 가 예외를 던지므로 isHittable 로 먼저 확인한다.
        if app.buttons["addplan.back"].isHittable {
            app.buttons["addplan.back"].tap()
            settle(1.0)
        }
    }

    // MARK: - 예산 상세

    /// 피드 — 견적 후기 목록과 상세.
    ///
    /// **금액이 맨 왼쪽 위에 혼자 크게** 와야 한다(시안 D). 이 화면에서 사람이 하는
    /// 일이 금액을 위아래로 훑는 것이라, 같은 x 좌표에 세로로 줄서야 비교가 된다.
    func test_04c_피드() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(2.0)

        let feedTab = app.buttons["tab.feed"]
        guard feedTab.waitForExistence(timeout: 10) else { return }
        feedTab.tap()
        settle(2.5)
        capture(app, "07-feed-list")

        // 카테고리 칩으로 좁혀 본다. 칩은 **마스터 목록**이라 스크롤해도 안 늘어난다.
        let chip = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "스튜디오")
        ).firstMatch
        if chip.isHittable {
            chip.tap()
            settle(1.5)
            capture(app, "07b-feed-filtered")
        }

        // 카드를 누르면 상세. **요청이 한 건도 안 나간다** — 목록이 항목을 넘긴다.
        let card = app.otherElements["feed.card"].firstMatch
        if card.waitForExistence(timeout: 5) {
            card.tap()
            settle(2.0)
            capture(app, "08-feed-detail")
        }
    }

    /// 홈의 `추가` → 등록 시트.
    ///
    /// **단계형이라 결제 유형을 고르기 전에는 금액·장소 칸이 없다.** 그래서 두 번
    /// 찍는다 — 고르기 전(제목·카테고리만)과 고른 뒤(금액·결제 체크·일자·시각).
    func test_04b_등록_시트() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        let add = app.buttons["추가"].firstMatch
        guard add.waitForExistence(timeout: 10) else { return }
        add.tap()
        settle(2.0)
        capture(app, "10-add-plan-empty")

        let title = app.textFields["addplan.title"]
        if title.waitForExistence(timeout: 5) {
            title.tap()
            title.typeText("본식 스냅")
            settle(1.0)
            capture(app, "11-add-plan-title")
        }

        // 카테고리를 고르면 결제 유형 줄이 열린다.
        let category = app.buttons["addplan.category"]
        if category.isHittable {
            category.tap()
            settle(1.2)
            capture(app, "12-add-plan-category-modal")
            let first = app.buttons.containing(
                NSPredicate(format: "label CONTAINS %@", "스튜디오")
            ).firstMatch
            if first.isHittable { first.tap() }
            settle(1.2)
        }

        // 결제 유형을 고르면 금액·일자·시각·위치·메모가 함께 나온다.
        let cash = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "현금")
        ).firstMatch
        if cash.isHittable {
            cash.tap()
            settle(1.2)
            capture(app, "13-add-plan-rest")
        }

        // 금액 아래의 "이미 결제했어요" — 완료와 다른 축이다.
        let paid = app.buttons["addplan.paid"]
        if paid.isHittable {
            paid.tap()
            settle(1.0)
            capture(app, "14-add-plan-paid")
        }
    }

    /// 메인의 예산 카드 → 예산 상세. 툴팁·탭·카테고리 필터·AI 안내까지 한 번에 돈다.
    func test_05_예산_상세() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        guard app.buttons["main.budget"].waitForExistence(timeout: 10) else { return }
        app.buttons["main.budget"].tap()
        settle(3.0)
        capture(app, "16-budget-detail")

        // 잔액 툴팁 단계는 없앴다 — `남은 금액` 과 `사용 후 잔액` 이 같은 도넛의
        // 구간이 되면서 물음표로 해명할 일이 없어졌다.

        // 카테고리 막대를 누르면 아래 목록이 그 카테고리로 좁혀진다.
        let bar = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "웨딩홀")
        ).firstMatch
        if bar.isHittable {
            bar.tap()
            settle(2.5)
            capture(app, "18-budget-category-filtered")
        }

        // 탭과 리스트는 화면 아래라 스크롤해야 눌린다.
        app.swipeUp()
        settle(1.5)
        capture(app, "19-budget-list")

        // 사용 탭 (필터가 걸린 상태라 웨딩홀 항목만 보여야 한다)
        if app.buttons["budget.tab.used"].isHittable {
            app.buttons["budget.tab.used"].tap()
            settle(2.5)
            capture(app, "19b-budget-used-tab")
        }

        // 다시 위로 올려 필터 해제 칩을 누른다.
        app.swipeDown()
        settle(1.5)

        if app.buttons["budget.clearFilter"].isHittable {
            app.buttons["budget.clearFilter"].tap()
            settle(2.5)
            capture(app, "20-budget-filter-cleared")
        }

        if app.buttons["budget.ai"].isHittable {
            app.buttons["budget.ai"].tap()
            settle(1.5)
            capture(app, "21-budget-ai-modal")
            if app.buttons["budget.ai.close"].isHittable {
                app.buttons["budget.ai.close"].tap()
                settle(1.0)
            }
        }

        if app.buttons["budget.back"].isHittable {
            app.buttons["budget.back"].tap()
            settle(1.5)
        }
    }

    // MARK: - 캘린더

    /// 메인의 캘린더 아이콘 → 달력. 달 이동과 날짜 시트까지 돈다.
    func test_06_캘린더() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        guard app.buttons["main.calendar"].waitForExistence(timeout: 10) else { return }
        app.buttons["main.calendar"].tap()
        settle(3.0)
        capture(app, "22-calendar")

        // 다음 달 — 이번 달에만 플랜이 있으므로 빈 격자가 나온다.
        if app.buttons["다음 달"].isHittable {
            app.buttons["다음 달"].tap()
            settle(2.5)
            capture(app, "23-calendar-next-month")
            app.buttons["이전 달"].tap()
            settle(2.5)
        }

        // 오늘 칸에는 플랜이 3개라 "+1" 이 붙는다. 눌러서 시트를 연다.
        let today = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "calendar.day.")
        )
        var opened = false
        for index in 0..<today.count where !opened {
            let cell = today.element(boundBy: index)
            // 플랜이 들어 있는 칸을 고른다 (라벨에 제목이 섞여 있다).
            if cell.isHittable, cell.label.contains("헤어") {
                cell.tap()
                settle(2.0)
                capture(app, "24-calendar-day-sheet")
                opened = true
            }
        }

        if !opened, today.element(boundBy: 0).isHittable {
            today.element(boundBy: 0).tap()
            settle(2.0)
            capture(app, "24-calendar-day-sheet")
        }

        if app.buttons["calendar.sheet.confirm"].isHittable {
            app.buttons["calendar.sheet.confirm"].tap()
            settle(1.5)
        }

        if app.buttons["calendar.close"].isHittable {
            app.buttons["calendar.close"].tap()
            settle(1.5)
        }
    }

    // MARK: - 채팅

    /// 참여 플랜 → 채팅방. 날짜 구분선·일정 카드·이름 변경 시트까지 남긴다.
    func test_07_채팅() {
        let app = makeApp()
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)

        guard app.buttons["tab.rooms"].waitForExistence(timeout: 10) else { return }
        app.buttons["tab.rooms"].tap()
        settle(3.0)

        // 첫 번째 방의 채팅방 행
        let chatRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "planlist.chat.")
        ).firstMatch
        guard chatRow.waitForExistence(timeout: 10), chatRow.isHittable else { return }
        chatRow.tap()
        settle(3.5)
        capture(app, "25-chat")

        // 입력 중인 모습
        let input = app.textFields["chat.input"]
        if input.isHittable {
            input.tap()
            input.typeText("네 좋아요")
            settle(1.5)
            capture(app, "26-chat-typing")
        }

        // 채팅방 이름 변경 시트
        if app.buttons["chat.menu"].isHittable {
            app.buttons["chat.menu"].tap()
            settle(1.5)
            capture(app, "27-chat-rename")
            app.swipeDown()
            settle(1.5)
        }

        if app.buttons["chat.back"].isHittable {
            app.buttons["chat.back"].tap()
            settle(1.5)
        }
    }

    // MARK: - 공유 참여

    /// 공유 링크로 진입 → 자동 참여 → 참여 플랜 목록.
    func test_08_공유_참여() {
        let app = makeApp(shareCode: "DEMO-SHARE")
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)

        // 참여가 끝나면 참여 플랜 목록으로 넘어간다.
        // ("공유 플랜 연결 중..." 은 데모에서 200ms 만에 지나가 찍히지 않는다)
        settle(4.5)
        capture(app, "28-share-joined")
    }

    /// 비로그인으로 공유 링크를 열면 로그인 안내가 뜬다.
    func test_09_공유_참여_비로그인() {
        let app = makeApp(loggedOut: true, shareCode: "DEMO-SHARE")
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 30)
        settle(3.0)
        capture(app, "29-share-login-required")
    }
}
