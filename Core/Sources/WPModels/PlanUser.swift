import Foundation

/// `GET /plan/user` (및 `GET /plan/room/{roomId}`) 응답 페이로드.
///
/// 웹의 `app/main/page.tsx:PlanUserData` 를 그대로 옮긴 것.
/// 신규 가입 직후에는 `name` / `weddingDate` / `budget` 이 비어 있을 수 있으므로 모두 optional.
public struct PlanUser: Codable, Hashable, Sendable {
    public var id: String?
    public var name: String?
    public var weddingDate: String?
    /// 백엔드가 문자열 숫자를 보내는 경우가 있어 관대하게 디코딩한다.
    @LooseInt public var budget: Int?
    public var roomId: Int?
    public var members: [Member]?
    public var chatRooms: [ChatRoom]?
    public var hasSeenMainGuide: Bool?
    public var hasSeenBudgetGuide: Bool?
    public var hasSeenChatGuide: Bool?
    public var requiredAgreementDate: String?
    public var adAgreementDate: String?

    public init(
        id: String? = nil,
        name: String? = nil,
        weddingDate: String? = nil,
        budget: Int? = nil,
        roomId: Int? = nil,
        members: [Member]? = nil,
        chatRooms: [ChatRoom]? = nil,
        hasSeenMainGuide: Bool? = nil,
        hasSeenBudgetGuide: Bool? = nil,
        hasSeenChatGuide: Bool? = nil,
        requiredAgreementDate: String? = nil,
        adAgreementDate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.weddingDate = weddingDate
        self._budget = LooseInt(wrappedValue: budget)
        self.roomId = roomId
        self.members = members
        self.chatRooms = chatRooms
        self.hasSeenMainGuide = hasSeenMainGuide
        self.hasSeenBudgetGuide = hasSeenBudgetGuide
        self.hasSeenChatGuide = hasSeenChatGuide
        self.requiredAgreementDate = requiredAgreementDate
        self.adAgreementDate = adAgreementDate
    }
}

/// `GET /plan/user/total-amount` 응답 페이로드. 단위는 만원.
///
/// 금액은 소수로 내려올 수 있어 `@LooseInt` 로 받는다.
/// 그냥 `Int` 로 두면 `2150.5` 하나에 응답 전체 디코딩이 실패한다.
public struct TotalAmount: Codable, Hashable, Sendable {
    @LooseInt public var totalAmount: Int?
    @LooseInt public var usedAmount: Int?
    @LooseInt public var remainingAmount: Int?

    public init(totalAmount: Int? = nil, usedAmount: Int? = nil, remainingAmount: Int? = nil) {
        self._totalAmount = LooseInt(wrappedValue: totalAmount)
        self._usedAmount = LooseInt(wrappedValue: usedAmount)
        self._remainingAmount = LooseInt(wrappedValue: remainingAmount)
    }
}

/// `GET /plan/user/amount/detail` 응답 페이로드. 단위는 만원.
public struct AmountDetail: Codable, Hashable, Sendable {
    public var initialCapital: Int
    public var totalPlannedAndUsedAmount: Int
    public var plannedUseAmount: Int
    public var usedAmount: Int

    /// 웹 StatCard 의 "남은 금액" — 초기 자본에서 **예정과 사용을 모두** 뺀 값.
    public var remaining: Int { initialCapital - (plannedUseAmount + usedAmount) }

    /// 웹 SpendingAnalysis 의 "사용 후 잔액" — **사용만** 뺀 값.
    ///
    /// - Important: 위 ``remaining`` 과 **다른 수치다.** 화면에서 둘 다 쓰이므로 헷갈리면 안 된다.
    ///   웹·안드로이드도 같은 주의사항을 주석으로 달아뒀다.
    public var savings: Int { initialCapital - usedAmount }

    /// 전체 사용률(%). 초기 자본이 0이면 0.
    public var usedPercent: Int {
        guard initialCapital > 0 else { return 0 }
        return Int((Double(usedAmount) / Double(initialCapital)) * 100)
    }

    public init(
        initialCapital: Int,
        totalPlannedAndUsedAmount: Int,
        plannedUseAmount: Int,
        usedAmount: Int
    ) {
        self.initialCapital = initialCapital
        self.totalPlannedAndUsedAmount = totalPlannedAndUsedAmount
        self.plannedUseAmount = plannedUseAmount
        self.usedAmount = usedAmount
    }
}

/// 약관 동의 정보. 게스트가 동의한 뒤 로그인 시 백엔드로 동기화된다.
public struct AgreementData: Codable, Hashable, Sendable {
    public var requiredAgreementDate: String
    public var adAgreementDate: String?

    public init(requiredAgreementDate: String, adAgreementDate: String? = nil) {
        self.requiredAgreementDate = requiredAgreementDate
        self.adAgreementDate = adAgreementDate
    }
}

/// 미읽음 메시지 수 (`GET /plan/chat/message/count/{roomId}`).
public struct UnreadCount: Codable, Hashable, Sendable {
    public var count: Int

    public init(count: Int) {
        self.count = count
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

/// 로그인 응답 (`POST /plan/auth/kakao/login`). 앱 자체 JWT를 담는다.
public struct AuthToken: Codable, Hashable, Sendable {
    public var token: String

    public init(token: String) {
        self.token = token
    }
}
