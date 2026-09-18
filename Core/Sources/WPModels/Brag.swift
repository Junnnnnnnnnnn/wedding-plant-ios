import Foundation

/// 자랑하기 한 장. 웹 `types/index.ts:BragPost` · `GET /plan/brag/list`
///
/// **단위는 플랜 전체다.** 홈 예산 패널의 토글을 켜면 내 웨딩 플랜 한 장이 통째로
/// 목록에 올라간다. 일정 하나를 올리는 일은 피드(견적 후기)가 이미 맡고 있다.
///
/// ## 피드와 규칙이 정반대다
///
/// 피드는 응답에 `planUserId` 조차 넣지 않는 철저한 익명인데, **자랑하기는 닉네임을
/// 내는 것이 목적**이다. 두 모듈의 코드를 서로 베낄 때 여기서 가장 먼저 사고가
/// 난다 — 피드에 이름을 흘리거나, 자랑하기에 익명 처리를 넣거나.
///
/// ## 올린 것은 스냅샷이 아니라 라이브다
///
/// `plan_brag` 에는 "올렸다" 는 사실만 있고(누가·언제부터·좋아요), 예산·개수·
/// 카테고리·플랜 목록은 **볼 때마다 그 사람의 지금 플랜에서 새로 만든다.**
///
/// 처음에는 스냅샷으로 만들었는데 틀렸다. 원래 규칙인 "수정하지 못하고 볼 수만
/// 있다" 는 **보는 사람** 이야기인데 그걸 올린 사람까지 묶는 것으로 잘못 읽었다.
/// 그러면 켠 뒤에 일정을 고쳐도 자랑하기가 얼어붙은 채로 남는다.
public struct BragPost: Codable, Hashable, Sendable, Identifiable {
    public var bragId: Int
    /// `"지수 · 현우"`. 방에 배우자가 있으면 두 이름.
    public var nickname: String
    public var weddingDate: String?
    /// 남은 일수. `"D-66"` 문장은 화면이 만든다.
    public var dday: Int?
    public var totalBudget: Int
    /// 실제 지출.
    public var usedAmount: Int
    /// 아직 안 쓴 예정 몫.
    public var plannedAmount: Int
    public var planCount: Int
    public var doneCount: Int
    /// 카드 칩으로 낼 카테고리 이름. 지출 큰 순.
    public var categories: [String]
    public var likeCount: Int
    public var liked: Bool
    public var publishedAt: String?
    public var isMine: Bool

    public var id: Int { bragId }

    public init(
        bragId: Int = 0,
        nickname: String = "",
        weddingDate: String? = nil,
        dday: Int? = nil,
        totalBudget: Int = 0,
        usedAmount: Int = 0,
        plannedAmount: Int = 0,
        planCount: Int = 0,
        doneCount: Int = 0,
        categories: [String] = [],
        likeCount: Int = 0,
        liked: Bool = false,
        publishedAt: String? = nil,
        isMine: Bool = false
    ) {
        self.bragId = bragId
        self.nickname = nickname
        self.weddingDate = weddingDate
        self.dday = dday
        self.totalBudget = totalBudget
        self.usedAmount = usedAmount
        self.plannedAmount = plannedAmount
        self.planCount = planCount
        self.doneCount = doneCount
        self.categories = categories
        self.likeCount = likeCount
        self.liked = liked
        self.publishedAt = publishedAt
        self.isMine = isMine
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bragId = try c.decodeIfPresent(Int.self, forKey: .bragId) ?? 0
        self.nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        self.weddingDate = try c.decodeIfPresent(String.self, forKey: .weddingDate)
        self.dday = try c.decodeIfPresent(Int.self, forKey: .dday)
        self.totalBudget = try c.decode(LooseInt.self, forKey: .totalBudget).wrappedValue ?? 0
        self.usedAmount = try c.decode(LooseInt.self, forKey: .usedAmount).wrappedValue ?? 0
        self.plannedAmount = try c.decode(LooseInt.self, forKey: .plannedAmount).wrappedValue ?? 0
        self.planCount = try c.decodeIfPresent(Int.self, forKey: .planCount) ?? 0
        self.doneCount = try c.decodeIfPresent(Int.self, forKey: .doneCount) ?? 0
        self.categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
        self.likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        self.liked = try c.decodeIfPresent(Bool.self, forKey: .liked) ?? false
        self.publishedAt = try c.decodeIfPresent(String.self, forKey: .publishedAt)
        self.isMine = try c.decodeIfPresent(Bool.self, forKey: .isMine) ?? false
    }
}

public struct BragPage: Codable, Hashable, Sendable {
    public var total: Int
    public var list: [BragPost]

    public init(total: Int = 0, list: [BragPost] = []) {
        self.total = total
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try c.decodeIfPresent([BragPost].self, forKey: .list) ?? []
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? self.list.count
    }
}

/// 예산 막대·범례용. 지출 큰 순.
public struct BragChartItem: Codable, Hashable, Sendable, Identifiable {
    public var categoryName: String
    public var usedAmount: Int

    public var id: String { categoryName }

    public init(categoryName: String = "", usedAmount: Int = 0) {
        self.categoryName = categoryName
        self.usedAmount = usedAmount
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.usedAmount = try c.decode(LooseInt.self, forKey: .usedAmount).wrappedValue ?? 0
    }
}

/// 상세에 뜨는 플랜 한 줄.
///
/// **시각(`startTime`)과 메모(`memo`)는 없다** — 남에게 공개할 값이 아니다.
///
/// 공개 범위는 안내 모달의 문구가 상한이다:
/// > 닉네임 · 결혼식 날짜 · 총예산 · 카테고리별 지출과 소계 · 일정 제목 ·
/// > 일정별 금액 · 일정 장소
///
/// **이 목록을 늘리려면 그 문구를 먼저 고친다.** 순서를 뒤집으면 동의받지 않은
/// 것을 공개하게 된다.
public struct BragPlanItem: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var categoryName: String
    public var title: String
    public var amount: Int?
    public var startDate: String?
    public var status: String?
    /// 돈이 나갔는지. **`status` 와 다른 축이다.**
    public var isPaidRaw: Bool?
    /// 장소. 카카오에서 고른 경우 **주소가 아니라 업체명**이다.
    public var location: String?
    public var lat: Double?
    public var lng: Double?

    enum CodingKeys: String, CodingKey {
        case id, categoryName, title, amount, startDate, status, location, lat, lng
        case isPaidRaw = "isPaid"
    }

    /// **좌표 `0, 0` 은 "없음" 이다.** 카카오 검색이 국내만 찾아서 해외 장소가
    /// 그렇게 저장된다 — `nil` 만 걸러 내면 기니 만 앞바다에 빈 지도가 그려진다.
    /// 실제로 푸꾸옥 호텔이 백지로 떴다.
    public var hasCoordinates: Bool {
        guard let lat, let lng else { return false }
        return lat != 0 || lng != 0
    }

    public init(
        id: Int = 0,
        categoryName: String = "",
        title: String = "",
        amount: Int? = nil,
        startDate: String? = nil,
        status: String? = nil,
        isPaid: Bool? = nil,
        location: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil
    ) {
        self.id = id
        self.categoryName = categoryName
        self.title = title
        self.amount = amount
        self.startDate = startDate
        self.status = status
        self.isPaidRaw = isPaid
        self.location = location
        self.lat = lat
        self.lng = lng
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.amount = try c.decode(LooseInt.self, forKey: .amount).wrappedValue
        self.startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.isPaidRaw = try c.decodeIfPresent(Bool.self, forKey: .isPaidRaw)
        self.location = try c.decodeIfPresent(String.self, forKey: .location)
        self.lat = try c.decodeIfPresent(Double.self, forKey: .lat)
        self.lng = try c.decodeIfPresent(Double.self, forKey: .lng)
    }
}

extension BragPlanItem: SchedulePayable {
    public var statusRawValue: String? { status }
}

/// 상세. `GET /plan/brag/{bragId}` — 카드 값 + 카테고리 차트 + **평평한** 플랜 목록.
///
/// 카테고리로 묶고 소계를 내는 것은 **화면이 한다** — 서버에 두면 문구 하나
/// 고치는 데 백엔드 배포가 묶인다.
public struct BragDetail: Codable, Hashable, Sendable {
    public var bragId: Int
    public var nickname: String
    public var weddingDate: String?
    public var dday: Int?
    public var totalBudget: Int
    public var usedAmount: Int
    public var plannedAmount: Int
    public var planCount: Int
    public var doneCount: Int
    public var categories: [String]
    public var likeCount: Int
    public var liked: Bool
    public var publishedAt: String?
    public var isMine: Bool
    public var categoryChart: [BragChartItem]
    public var items: [BragPlanItem]

    public init(
        bragId: Int = 0,
        nickname: String = "",
        weddingDate: String? = nil,
        dday: Int? = nil,
        totalBudget: Int = 0,
        usedAmount: Int = 0,
        plannedAmount: Int = 0,
        planCount: Int = 0,
        doneCount: Int = 0,
        categories: [String] = [],
        likeCount: Int = 0,
        liked: Bool = false,
        publishedAt: String? = nil,
        isMine: Bool = false,
        categoryChart: [BragChartItem] = [],
        items: [BragPlanItem] = []
    ) {
        self.bragId = bragId
        self.nickname = nickname
        self.weddingDate = weddingDate
        self.dday = dday
        self.totalBudget = totalBudget
        self.usedAmount = usedAmount
        self.plannedAmount = plannedAmount
        self.planCount = planCount
        self.doneCount = doneCount
        self.categories = categories
        self.likeCount = likeCount
        self.liked = liked
        self.publishedAt = publishedAt
        self.isMine = isMine
        self.categoryChart = categoryChart
        self.items = items
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bragId = try c.decodeIfPresent(Int.self, forKey: .bragId) ?? 0
        self.nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? ""
        self.weddingDate = try c.decodeIfPresent(String.self, forKey: .weddingDate)
        self.dday = try c.decodeIfPresent(Int.self, forKey: .dday)
        self.totalBudget = try c.decode(LooseInt.self, forKey: .totalBudget).wrappedValue ?? 0
        self.usedAmount = try c.decode(LooseInt.self, forKey: .usedAmount).wrappedValue ?? 0
        self.plannedAmount = try c.decode(LooseInt.self, forKey: .plannedAmount).wrappedValue ?? 0
        self.planCount = try c.decodeIfPresent(Int.self, forKey: .planCount) ?? 0
        self.doneCount = try c.decodeIfPresent(Int.self, forKey: .doneCount) ?? 0
        self.categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
        self.likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        self.liked = try c.decodeIfPresent(Bool.self, forKey: .liked) ?? false
        self.publishedAt = try c.decodeIfPresent(String.self, forKey: .publishedAt)
        self.isMine = try c.decodeIfPresent(Bool.self, forKey: .isMine) ?? false
        self.categoryChart = try c.decodeIfPresent([BragChartItem].self, forKey: .categoryChart) ?? []
        self.items = try c.decodeIfPresent([BragPlanItem].self, forKey: .items) ?? []
    }
}

/// 내 플랜이 지금 올라가 있는지. `GET /plan/brag/my`
public struct BragMyStatus: Codable, Hashable, Sendable {
    public var published: Bool
    public var bragId: Int?
    public var publishedAt: String?
    public var likeCount: Int

    public init(published: Bool = false, bragId: Int? = nil, publishedAt: String? = nil, likeCount: Int = 0) {
        self.published = published
        self.bragId = bragId
        self.publishedAt = publishedAt
        self.likeCount = likeCount
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.published = try c.decodeIfPresent(Bool.self, forKey: .published) ?? false
        self.bragId = try c.decodeIfPresent(Int.self, forKey: .bragId)
        self.publishedAt = try c.decodeIfPresent(String.self, forKey: .publishedAt)
        self.likeCount = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
    }
}

/// `POST`/`DELETE /plan/brag/like/{id}` 응답.
public struct BragLikeResult: Codable, Hashable, Sendable {
    public var likeCount: Int?
    public var liked: Bool?

    public init(likeCount: Int? = nil, liked: Bool? = nil) {
        self.likeCount = likeCount
        self.liked = liked
    }
}
