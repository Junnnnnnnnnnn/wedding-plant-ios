import Foundation
import WPModels
import WPUtils

/// 로그인 성공 직후 사용자를 어디로 보낼지.
public enum PostLoginDestination: Equatable, Sendable {
    /// 공유 링크로 들어온 경우 — 방 참여 API 호출 후 참여 플랜 목록으로.
    case joinSharedRoom(shareCode: String)
    /// 로그인 전 보고 있던 화면으로 복귀.
    case returnPath(String)
    /// 플랜이 이미 완성된 기존 사용자.
    case main
    /// 개인 플랜은 없지만 참여 중인 방이 있는 사용자.
    case planList
    /// 비로그인 상태로 플랜을 짜던 게스트 — 로컬 데이터를 백엔드로 올린 뒤 메인으로.
    case migrateGuestData(weddingDate: KstDate)
    /// 신규 사용자 — 초기 설정 화면.
    case setting
}

/// 라우팅 판단에 필요한 입력 일체.
public struct PostLoginContext: Sendable, Equatable {
    /// 로그인 전에 저장해 둔 공유 코드 (웹의 `plan_share_after_login`).
    public var shareCode: String?
    /// 로그인 전에 저장해 둔 복귀 경로 (웹의 `plan_return_path_after_login`).
    public var returnPath: String?
    /// `GET /plan/user` 결과. 호출 실패 시 `nil`.
    public var user: PlanUser?
    /// `GET /plan/room/list` 의 `total`. 호출 실패 시 0.
    public var joinedRoomCount: Int
    /// 로그인 시도 시점에 메인 화면에 있었는지 (웹의 `pathname === "/main"`).
    public var isOnMainScreen: Bool
    /// 게스트 초기 설정을 실제로 마쳤는지 (웹의 `HAS_COMPLETED_GUEST_SETTING_KEY`).
    public var hasCompletedGuestSetting: Bool
    /// 게스트가 로컬에 입력해 둔 결혼일.
    public var guestWeddingDate: KstDate?
    /// 게스트가 로컬에 입력해 둔 이름.
    public var guestName: String?

    public init(
        shareCode: String? = nil,
        returnPath: String? = nil,
        user: PlanUser? = nil,
        joinedRoomCount: Int = 0,
        isOnMainScreen: Bool = false,
        hasCompletedGuestSetting: Bool = false,
        guestWeddingDate: KstDate? = nil,
        guestName: String? = nil
    ) {
        self.shareCode = shareCode
        self.returnPath = returnPath
        self.user = user
        self.joinedRoomCount = joinedRoomCount
        self.isOnMainScreen = isOnMainScreen
        self.hasCompletedGuestSetting = hasCompletedGuestSetting
        self.guestWeddingDate = guestWeddingDate
        self.guestName = guestName
    }
}

/// 로그인 후 분기 결정.
///
/// 웹 `KakaoLoginAlert` 의 250줄짜리 effect에서 **라우팅 판단만** 뽑아낸 순수 함수다.
/// 네트워크 호출·상태 변경 같은 부수효과는 App 레이어가 수행하고, 여기서는 오직 목적지만 정한다.
/// 덕분에 이 분기 전체를 Windows에서 유닛테스트로 검증할 수 있다.
///
/// 우선순위(웹과 동일, 순서를 바꾸면 회귀):
/// `shareCode` → `returnPath` → 플랜 완성된 기존 사용자 → 참여 방 보유 → 진짜 게스트 → 신규 사용자
public enum PostLoginRouter {
    public static func destination(for context: PostLoginContext) -> PostLoginDestination {
        if let shareCode = context.shareCode?.trimmingCharacters(in: .whitespaces),
           !shareCode.isEmpty {
            return .joinSharedRoom(shareCode: shareCode)
        }

        if let returnPath = context.returnPath?.trimmingCharacters(in: .whitespaces),
           !returnPath.isEmpty {
            return .returnPath(returnPath)
        }

        if PlanCompletion.isComplete(context.user) {
            return .main
        }

        if context.joinedRoomCount > 0 {
            return .planList
        }

        // 웹 주석: HAS_COMPLETED_GUEST_SETTING_KEY 플래그가 있어야만 '진짜' 게스트 체험 유저.
        // 신규 사용자가 게스트 마이그레이션 경로로 잘못 빠지는 것을 막는 보호 장치다.
        if context.isOnMainScreen,
           context.hasCompletedGuestSetting,
           let weddingDate = context.guestWeddingDate {
            return .migrateGuestData(weddingDate: weddingDate)
        }

        return .setting
    }

    /// 진행 전에 이름 입력 모달을 띄워야 하는지.
    ///
    /// 웹에서도 공유 링크 참여와 게스트 마이그레이션, 두 분기에서만 이름을 물어본다.
    public static func requiresNameInput(
        destination: PostLoginDestination,
        context: PostLoginContext
    ) -> Bool {
        switch destination {
        case .joinSharedRoom:
            return isBlank(context.user?.name)
        case .migrateGuestData:
            return isBlank(context.guestName)
        case .returnPath, .main, .planList, .setting:
            return false
        }
    }

    private static func isBlank(_ value: String?) -> Bool {
        (value ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }
}
