import Foundation
import WPModels

/// 준비 패스 상품. App Store Connect 의 상품 ID 와 서버의 `plan` 값을 잇는다.
///
/// 월간·년간은 **비갱신 구독**(다시 살 수 있고 남은 기간 뒤에 이어 붙음), 평생은 **비소모성**이다.
public enum PassProduct: String, CaseIterable, Sendable {
    case monthly = "prep_pass_monthly"
    case yearly = "prep_pass_yearly"
    case lifetime = "prep_pass_lifetime"

    public var id: String { rawValue }

    /// 서버 `GetPlanPassResponse.plan` 값
    public var serverPlan: String {
        switch self {
        case .monthly: return "MONTHLY"
        case .yearly: return "YEARLY"
        case .lifetime: return "LIFETIME"
        }
    }

    public init?(serverPlan: String?) {
        guard let plan = serverPlan?.uppercased(), let found = Self.allCases.first(where: { $0.serverPlan == plan }) else { return nil }
        self = found
    }
}

/// 결제 하나가 끝난 모양 — 안드로이드 `PassPurchaseResult` 와 같은 갈래.
public enum PassPurchaseOutcome: Equatable, Sendable {
    /// 서버가 확인하고 패스를 켰다
    case success(PassState)
    /// 사용자가 결제창을 닫았다 — **오류 안내를 띄우지 않는다**
    case canceled
    /// 실패가 아니라 기다리는 중(승인 대기 · 돈은 나갔는데 서버가 아직 못 받음). 빨간 오류로 그리면 한 번 더 결제한다
    case pending(String)
    /// 결제 없이 끝났다(이미 평생 · 서버가 받지 않음 · 결제할 방에 이미 패스). 그 방의 지금 패스가 있으면 함께
    case settled(PassState?, String)
    /// 진짜 실패
    case failed(String)

    public var message: String? {
        switch self {
        case .success, .canceled: return nil
        case let .pending(text), let .failed(text): return text
        case let .settled(_, text): return text
        }
    }

    /// 빨갛게 그릴 안내인가 — 대기·결제 없이 끝남은 회색이다
    public var isError: Bool { if case .failed = self { return true }; return false }
}

/// 준비 패스 결제의 판정·문장 — StoreKit·화면에 기대지 않는 부분(안드로이드 `PassBilling`·`PassViewModel` 의 문구와 같다).
public enum PassPurchaseRules {
    // MARK: 문장

    /// 결제할 방을 서버에서 받지 못했을 때(웹 `ENSURE_ROOM_FAILED`)
    public static let ensureFailed = "결제를 준비하지 못했어요. 잠시 후 다시 시도해 주세요."
    /// 남의 플랜·공유 미리보기에서 결제를 눌렀을 때 — 화면의 방과 서버의 내 방이 다르다
    public static let notMyPlan = "준비 패스는 내 플랜에서 결제할 수 있어요."
    /// 결제할 방에 이미 패스가 켜져 있었을 때(화면이 보여 주지 않던 방으로 옮긴 경우)
    public static let alreadyActive = "이 플랜에는 이미 준비 패스가 있어요."
    public static let alreadyLifetime = "이미 평생 패스를 가지고 있어요."
    public static let stateCheckFailed = "패스 상태를 확인하지 못했어요. 잠시 후 다시 시도해 주세요."
    public static let productUnavailable = "상품 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
    public static let notCompleted = "결제가 완료되지 않았어요."
    /// StoreKit 이 거래 서명을 확인하지 못했다 — 패스를 켜지 않는다
    public static let unverified = "결제 정보를 확인하지 못해 패스를 켜지 않았어요. 잠시 후 다시 시도해 주세요."
    /// 승인 대기(자녀 구매 요청 · 결제 수단 확인). **실패가 아니다** — 승인되면 앱이 받아 켠다
    public static let pending = "결제 승인을 기다리는 중이에요. 승인되면 패스가 자동으로 켜집니다."
    /// 돈은 이미 나갔는데 서버가 못 받았다(네트워크·서버 오류). 거래를 끝내지 않아 앱을 다시 열면 다시 보낸다
    public static let chargedButNotApplied = "결제는 완료됐어요. 패스를 켜는 중에 문제가 생겼어요. 홈으로 돌아가거나 앱을 다시 열면 자동으로 다시 시도합니다."
    /// 평생 패스가 있는 방이라 서버가 받지 않았다. App Store 는 Google Play 처럼 저절로 환불하지 않아 요청할 곳을 말한다
    public static let lifetimeRefused = "이미 평생 패스가 있어 이번 결제는 승인하지 않았어요. 환불은 App Store 의 구매 내역에서 요청할 수 있어요."
    public static let ownerMismatch = "다른 계정에서 구매한 패스예요. 구매하신 계정으로 로그인해 주세요."
    public static let notVerified = "영수증을 확인하지 못했어요. 결제가 됐다면 앱을 다시 열면 켜집니다."

    // 구매 복원
    public static let restored = "구매를 복원했어요."
    public static let nothingToRestore = "복원할 구매가 없어요."
    public static let restoreFailed = "구매를 복원하지 못했어요. 잠시 후 다시 시도해 주세요."

    /// 서버가 받지 않기로 한 결제 — 다시 보내도 같은 답이라 거래를 끝낸다
    public static let lifetimeReason = "PASS_ALREADY_LIFETIME"

    // MARK: appAccountToken ↔ 방

    /// 방 id 를 담는 `appAccountToken`. `00000000-0000-4000-8000-` + 방 id 의 12자리 소문자 16진수(예 255 → `…-0000000000ff`).
    ///
    /// **결제창에 실어 보낸 방**이 곧 패스를 붙일 방이다(안드로이드 `obfuscatedProfileId`). 서버 확인이 실패해 나중에
    /// 복구할 때 이 값으로 보낸다 — 화면이 보고 있는 방(참여 중인 남의 방일 수 있음)으로 보내지 않는다.
    /// 버전 4 · RFC 4122 변형 자리를 지켜 App Store 가 받는 UUID 모양으로 둔다. 12자리를 넘는 id 는 담을 수 없어 nil.
    public static func appAccountToken(roomId: Int) -> UUID? {
        guard roomId > 0, roomId <= 0xFFFF_FFFF_FFFF else { return nil }
        let hex = String(roomId, radix: 16, uppercase: false)
        let tail = String(repeating: "0", count: 12 - hex.count) + hex
        return UUID(uuidString: "00000000-0000-4000-8000-" + tail)
    }

    /// `appAccountToken(roomId:)` 의 거꾸로. 우리 모양이 아니면(다른 앱 버전·토큰 없음) nil — 그때는 내 방으로 보낸다.
    public static func roomId(fromAppAccountToken token: UUID?) -> Int? {
        guard let text = token?.uuidString.lowercased() else { return nil }
        let prefix = "00000000-0000-4000-8000-"
        guard text.hasPrefix(prefix), let id = Int(text.dropFirst(prefix.count), radix: 16), id > 0 else { return nil }
        return id
    }

    // MARK: 판정

    /// 지금 쓰는 패스가 있는가(끝난 패스는 아님)
    public static func isActive(_ state: PassState) -> Bool { state.hasPass && !state.expired }

    /// 평생 패스를 쓰는 중인가 — 이 방에서는 더 팔지 않는다(서버도 `PASS_ALREADY_LIFETIME` 으로 받지 않는다)
    public static func isLifetime(_ state: PassState) -> Bool { isActive(state) && PassProduct(serverPlan: state.plan) == .lifetime }

    /// 서버 확인이 실패했을 때 할 말.
    ///
    /// - Parameter charged: 방금 결제창에서 돈이 나간 직후인가. 그때는 사유보다 **돈이 나갔다는 사실**이 먼저다 —
    ///   서버는 App Store 일시 장애도 `PURCHASE_NOT_VERIFIED` 로 돌려주는데, 빨간 "영수증을 확인하지 못했어요" 로 내면
    ///   다른 요금제로 또 결제한다. 승인 대기와 다른 계정 구매만 제 문구를 쓴다(안드로이드 `messageFor`).
    public static func verifyFailure(reason: String?, serverMessage: String?, charged: Bool) -> PassPurchaseOutcome {
        if charged, reason != "PURCHASE_PENDING", reason != "PURCHASE_OWNER_MISMATCH" {
            return .pending(chargedButNotApplied)
        }
        switch reason {
        case "PURCHASE_PENDING": return .pending(pending)
        case "PURCHASE_OWNER_MISMATCH": return .failed(ownerMismatch)
        case "PURCHASE_NOT_VERIFIED": return .failed(notVerified)
        default: return .failed(serverMessage?.isEmpty == false ? serverMessage! : notCompleted)
        }
    }
}
