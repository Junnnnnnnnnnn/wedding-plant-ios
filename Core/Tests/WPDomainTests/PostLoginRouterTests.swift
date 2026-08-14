import XCTest
import WPModels
import WPUtils
@testable import WPDomain

/// 웹 `KakaoLoginAlert` 의 250줄짜리 effect에서 가장 깨지기 쉬웠던 부분.
/// 분기 우선순위가 바뀌면 사용자가 엉뚱한 화면으로 떨어지므로 전 분기를 고정한다.
final class PostLoginRouterTests: XCTestCase {

    private let weddingDate = KstDate(year: 2026, month: 10, day: 10)!

    private func completeUser() -> PlanUser {
        PlanUser(name: "지수", weddingDate: "2026-10-10", budget: 5000)
    }

    // MARK: - 우선순위

    func test_shareCode가_최우선이다() {
        // 다른 모든 조건이 동시에 참이어도 공유 링크가 이긴다.
        let context = PostLoginContext(
            shareCode: "ABC123",
            returnPath: "/budget-detail",
            user: completeUser(),
            joinedRoomCount: 3,
            isOnMainScreen: true,
            hasCompletedGuestSetting: true,
            guestWeddingDate: weddingDate
        )
        XCTAssertEqual(PostLoginRouter.destination(for: context), .joinSharedRoom(shareCode: "ABC123"))
    }

    func test_returnPath는_shareCode_다음이다() {
        let context = PostLoginContext(
            returnPath: "/budget-detail",
            user: completeUser(),
            joinedRoomCount: 3,
            isOnMainScreen: true,
            hasCompletedGuestSetting: true,
            guestWeddingDate: weddingDate
        )
        XCTAssertEqual(PostLoginRouter.destination(for: context), .returnPath("/budget-detail"))
    }

    func test_플랜이_완성된_기존_사용자는_main이다() {
        let context = PostLoginContext(
            user: completeUser(),
            joinedRoomCount: 3,
            isOnMainScreen: true,
            hasCompletedGuestSetting: true,
            guestWeddingDate: weddingDate
        )
        XCTAssertEqual(PostLoginRouter.destination(for: context), .main)
    }

    func test_플랜은_없지만_참여방이_있으면_planList다() {
        let context = PostLoginContext(
            user: PlanUser(name: "지수"),
            joinedRoomCount: 1,
            isOnMainScreen: true,
            hasCompletedGuestSetting: true,
            guestWeddingDate: weddingDate
        )
        XCTAssertEqual(PostLoginRouter.destination(for: context), .planList)
    }

    func test_진짜_게스트는_마이그레이션이다() {
        let context = PostLoginContext(
            user: PlanUser(),
            joinedRoomCount: 0,
            isOnMainScreen: true,
            hasCompletedGuestSetting: true,
            guestWeddingDate: weddingDate
        )
        XCTAssertEqual(
            PostLoginRouter.destination(for: context),
            .migrateGuestData(weddingDate: weddingDate)
        )
    }

    func test_아무_조건도_없으면_setting이다() {
        XCTAssertEqual(PostLoginRouter.destination(for: PostLoginContext()), .setting)
    }

    // MARK: - 게스트 분기 보호 장치

    func test_게스트_설정을_마치지_않았으면_setting이다() {
        // 신규 사용자가 게스트 마이그레이션 경로로 새는 것을 막는 핵심 가드.
        let context = PostLoginContext(
            joinedRoomCount: 0,
            isOnMainScreen: true,
            hasCompletedGuestSetting: false,
            guestWeddingDate: weddingDate
        )
        XCTAssertEqual(PostLoginRouter.destination(for: context), .setting)
    }

    func test_메인화면이_아니면_게스트_마이그레이션을_하지_않는다() {
        let context = PostLoginContext(
            isOnMainScreen: false,
            hasCompletedGuestSetting: true,
            guestWeddingDate: weddingDate
        )
        XCTAssertEqual(PostLoginRouter.destination(for: context), .setting)
    }

    func test_게스트_결혼일이_없으면_setting이다() {
        let context = PostLoginContext(
            isOnMainScreen: true,
            hasCompletedGuestSetting: true,
            guestWeddingDate: nil
        )
        XCTAssertEqual(PostLoginRouter.destination(for: context), .setting)
    }

    // MARK: - 빈 문자열 방어

    func test_공백뿐인_shareCode와_returnPath는_무시된다() {
        let context = PostLoginContext(
            shareCode: "   ",
            returnPath: "",
            user: completeUser()
        )
        XCTAssertEqual(PostLoginRouter.destination(for: context), .main)
    }

    // MARK: - 이름 입력 요구

    func test_공유방_참여시_이름이_없으면_이름을_묻는다() {
        let context = PostLoginContext(shareCode: "ABC", user: PlanUser(name: "  "))
        let destination = PostLoginRouter.destination(for: context)
        XCTAssertTrue(PostLoginRouter.requiresNameInput(destination: destination, context: context))
    }

    func test_공유방_참여시_이름이_있으면_묻지_않는다() {
        let context = PostLoginContext(shareCode: "ABC", user: PlanUser(name: "지수"))
        let destination = PostLoginRouter.destination(for: context)
        XCTAssertFalse(PostLoginRouter.requiresNameInput(destination: destination, context: context))
    }

    func test_게스트_마이그레이션시_이름이_없으면_이름을_묻는다() {
        let context = PostLoginContext(
            isOnMainScreen: true,
            hasCompletedGuestSetting: true,
            guestWeddingDate: weddingDate,
            guestName: nil
        )
        let destination = PostLoginRouter.destination(for: context)
        XCTAssertEqual(destination, .migrateGuestData(weddingDate: weddingDate))
        XCTAssertTrue(PostLoginRouter.requiresNameInput(destination: destination, context: context))
    }

    func test_main_planList_setting_에서는_이름을_묻지_않는다() {
        let context = PostLoginContext(user: completeUser())
        for destination in [PostLoginDestination.main, .planList, .setting, .returnPath("/user")] {
            XCTAssertFalse(
                PostLoginRouter.requiresNameInput(destination: destination, context: context),
                "\(destination) 에서 이름을 물으면 안 됩니다"
            )
        }
    }
}

final class PlanCompletionTests: XCTestCase {

    func test_셋_다_있으면_완성이다() {
        XCTAssertTrue(PlanCompletion.isComplete(name: "지수", weddingDate: "2026-10-10", budget: 5000))
    }

    func test_예산_0원도_입력된_것으로_본다() {
        // 웹과 동일한 판정. 바꾸면 예산 0을 넣은 사용자가 설정 화면으로 되돌려진다.
        XCTAssertTrue(PlanCompletion.isComplete(name: "지수", weddingDate: "2026-10-10", budget: 0))
    }

    func test_하나라도_비면_미완성이다() {
        XCTAssertFalse(PlanCompletion.isComplete(name: nil, weddingDate: "2026-10-10", budget: 100))
        XCTAssertFalse(PlanCompletion.isComplete(name: "지수", weddingDate: nil, budget: 100))
        XCTAssertFalse(PlanCompletion.isComplete(name: "지수", weddingDate: "2026-10-10", budget: nil))
    }

    func test_공백만_있는_문자열은_비어있는_것이다() {
        XCTAssertFalse(PlanCompletion.isComplete(name: "   ", weddingDate: "2026-10-10", budget: 100))
        XCTAssertFalse(PlanCompletion.isComplete(name: "지수", weddingDate: "  ", budget: 100))
    }

    func test_user가_nil이면_미완성이다() {
        XCTAssertFalse(PlanCompletion.isComplete(nil))
    }
}
