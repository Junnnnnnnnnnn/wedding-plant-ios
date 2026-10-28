import Foundation

/// 견적 후기 한 장. 웹 `types/index.ts:FeedPost` · `GET /plan/feed/list`
///
/// **단위는 사진이 아니라 "완료된 일정 = 견적 후기"** 다. 결혼 준비의 1번 질문이
/// "이게 비싼 건가?" 인데 그 답이 될 값(업체명·실제 지출·지역)이 이미 일정에 들어
/// 있다. 글을 새로 쓰게 하지 않고 있는 값에 별점과 한 줄만 얹는다 — 콘텐츠 제작
/// 비용이 0 이라야 콜드 스타트를 넘긴다.
///
/// ## 익명이다 (백엔드와 짝, 타협하지 말 것)
///
/// 응답에 `planUserId` 가 **없다.** `"D-131 신부"` 문장은 `authorDDay`·`authorRole`
/// 로 화면이 만든다 — 서버가 완성된 문구를 내려보내면 문구를 고칠 때마다 백엔드
/// 배포에 묶인다.
public struct FeedPost: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var categoryName: String
    /// 업체명. **고른 장소 이름이 일정 제목을 이긴다** —
    /// 일정 제목은 `본식 촬영` 같은 개인 메모인 경우가 많다.
    public var title: String
    /// 실제 지출(만원).
    ///
    /// - Important: **비공개면 필드 자체가 없다.** `?? 0` 이나 `?? 0.0` 으로 채우지
    ///   말 것 — "0원" 으로 그려진다. `nil` 이면 "금액 비공개" 를 내야 한다.
    public var amount: Double?
    public var isAmountPublic: Bool
    /// 시/구 까지만. 필터에 쓴다. **백엔드가 자른다 — 앱에서 자르지 말 것.**
    /// 프론트에 맡기면 앱마다 다르게 자르고, 한 곳만 빠뜨려도 전체 주소가 올라간다.
    public var region: String?
    /// 도로명 주소. 카카오 장소를 고른 후기에만 있다.
    public var address: String?
    /// 카카오 장소 id. **같은 업체 후기를 묶는 유일한 열쇠**다 —
    /// 업체명은 자유 문자열이라 `SG웨딩홀` 과 `sg 웨딩홀` 이 서로 다른 업체가 된다.
    public var placeId: String?
    public var lat: Double?
    public var lng: Double?
    /// 만족도 1~5
    public var rating: Int
    public var body: String?
    /// 올린 시점의 남은 일수. `"D-131"` 문장은 화면이 만든다.
    public var authorDDay: Int?
    /// `"GROOM"` | `"BRIDE"` | `"UNKNOWN"`
    public var authorRole: String
    /// "도움이 돼요" 수.
    ///
    /// - Important: **"안 돼요" 수는 내려오지 않는다.** 정직하게 올린 후기에
    ///   "안 돼요 12" 가 박히면 다음 사람이 안 올린다 — 공급이 이 기능의 생사다.
    ///   정렬(도움순)과 어뷰징 감지는 서버가 안에서만 쓴다.
    ///   **화면에 숫자를 붙이지 말 것.**
    public var helpfulCount: Int
    /// 내가 어떻게 평가했는지. 안 했으면 `nil`. `"HELPFUL"` | `"NOT_HELPFUL"`
    public var myVote: String?
    public var isMine: Bool
    /// 사진 서명 주소(최대 3장, 순서 = 보여 주는 순서). 3시간짜리이고 정각에 맞춰 서명해 한 시간 동안은 같은
    /// 주소가 와서 캐시 키로 써도 된다. 예전 API·보관소 없는 환경은 빈 목록이다.
    public var images: [String]
    /// 사진 R2 키(`images` 와 같은 순서). **내 후기에만** 온다 — 고칠 때 남길 사진과 충돌 기준(`baseImages`)으로 쓴다.
    public var imageKeys: [String]?
    public var createDate: String?

    /// 좌표가 없거나 (0,0) 이면 지도를 띄우지 않는다.
    ///
    /// **`0, 0` 은 "없음" 이다** — 카카오 검색으로 고르지 않으면 `0.0` 이 들어가고,
    /// **해외 장소가 그렇게 저장된다**(카카오 검색이 국내만 찾는다).
    /// `nil` 만 걸러 내면 기니 만 앞바다에 마커가 찍힌 빈 지도가 그려진다.
    public var hasCoordinates: Bool {
        guard let lat, let lng else { return false }
        return lat != 0 || lng != 0
    }

    public init(
        id: Int = 0,
        categoryName: String = "",
        title: String = "",
        amount: Double? = nil,
        isAmountPublic: Bool = false,
        region: String? = nil,
        address: String? = nil,
        placeId: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        rating: Int = 0,
        body: String? = nil,
        authorDDay: Int? = nil,
        authorRole: String = "UNKNOWN",
        helpfulCount: Int = 0,
        myVote: String? = nil,
        isMine: Bool = false,
        images: [String] = [],
        imageKeys: [String]? = nil,
        createDate: String? = nil
    ) {
        self.id = id
        self.categoryName = categoryName
        self.title = title
        self.amount = amount
        self.isAmountPublic = isAmountPublic
        self.region = region
        self.address = address
        self.placeId = placeId
        self.lat = lat
        self.lng = lng
        self.rating = rating
        self.body = body
        self.authorDDay = authorDDay
        self.authorRole = authorRole
        self.helpfulCount = helpfulCount
        self.myVote = myVote
        self.isMine = isMine
        self.images = images
        self.imageKeys = imageKeys
        self.createDate = createDate
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        // **키가 없으면 nil 로 둔다.** 0 으로 채우면 "0원" 으로 그려진다.
        self.amount = try c.decode(LooseDouble.self, forKey: .amount).wrappedValue
        self.isAmountPublic = try c.decodeIfPresent(Bool.self, forKey: .isAmountPublic) ?? false
        self.region = try c.decodeIfPresent(String.self, forKey: .region)
        self.address = try c.decodeIfPresent(String.self, forKey: .address)
        self.placeId = try c.decodeIfPresent(String.self, forKey: .placeId)
        self.lat = try c.decodeIfPresent(LooseDouble.self, forKey: .lat)?.wrappedValue
        self.lng = try c.decodeIfPresent(LooseDouble.self, forKey: .lng)?.wrappedValue
        self.rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        self.body = try c.decodeIfPresent(String.self, forKey: .body)
        self.authorDDay = try c.decodeIfPresent(Int.self, forKey: .authorDDay)
        self.authorRole = try c.decodeIfPresent(String.self, forKey: .authorRole) ?? "UNKNOWN"
        self.helpfulCount = try c.decodeIfPresent(Int.self, forKey: .helpfulCount) ?? 0
        self.myVote = try c.decodeIfPresent(String.self, forKey: .myVote)
        self.isMine = try c.decodeIfPresent(Bool.self, forKey: .isMine) ?? false
        self.images = try c.decodeIfPresent([String].self, forKey: .images) ?? []
        self.imageKeys = try c.decodeIfPresent([String].self, forKey: .imageKeys)
        self.createDate = try c.decodeIfPresent(String.self, forKey: .createDate)
    }
}

/// `GET /plan/feed/list` 응답.
public struct FeedPage: Codable, Hashable, Sendable {
    public var total: Int
    public var list: [FeedPost]

    public init(total: Int = 0, list: [FeedPost] = []) {
        self.total = total
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try c.decodeIfPresent([FeedPost].self, forKey: .list) ?? []
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? self.list.count
    }
}

/// 피드 사이드의 "내 후기" 패널. `GET /plan/feed/my/status`
///
/// **공급이 이 기능의 생사**라 계속 상기시키는 자리다.
public struct FeedMyStatus: Codable, Hashable, Sendable {
    public var postCount: Int
    public var receivedHelpfulCount: Int
    public var postableScheduleCount: Int

    public init(postCount: Int = 0, receivedHelpfulCount: Int = 0, postableScheduleCount: Int = 0) {
        self.postCount = postCount
        self.receivedHelpfulCount = receivedHelpfulCount
        self.postableScheduleCount = postableScheduleCount
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.postCount = try c.decodeIfPresent(Int.self, forKey: .postCount) ?? 0
        self.receivedHelpfulCount = try c.decodeIfPresent(Int.self, forKey: .receivedHelpfulCount) ?? 0
        self.postableScheduleCount = try c.decodeIfPresent(Int.self, forKey: .postableScheduleCount) ?? 0
    }
}

/// 아직 후기로 안 올린 완료 일정. `GET /plan/feed/postable`
public struct PostableSchedule: Codable, Hashable, Sendable, Identifiable {
    public var scheduleId: Int
    public var categoryName: String
    public var title: String
    public var amount: Double?
    /// 일정에 적힌 장소. 카카오에서 고른 경우 주소가 아니라 **업체명**이다.
    /// 주소로 알고 파싱하면 지역이 늘 빈다(웹에서 실제로 겪은 버그).
    public var location: String?
    public var locationLat: Double?
    public var locationLng: Double?
    public var startDate: String?

    public var id: Int { scheduleId }

    public init(
        scheduleId: Int = 0,
        categoryName: String = "",
        title: String = "",
        amount: Double? = nil,
        location: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil,
        startDate: String? = nil
    ) {
        self.scheduleId = scheduleId
        self.categoryName = categoryName
        self.title = title
        self.amount = amount
        self.location = location
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.startDate = startDate
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.scheduleId = try c.decodeIfPresent(Int.self, forKey: .scheduleId) ?? 0
        self.categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.amount = try c.decode(LooseDouble.self, forKey: .amount).wrappedValue
        self.location = try c.decodeIfPresent(String.self, forKey: .location)
        self.locationLat = try c.decodeIfPresent(LooseDouble.self, forKey: .locationLat)?.wrappedValue
        self.locationLng = try c.decodeIfPresent(LooseDouble.self, forKey: .locationLng)?.wrappedValue
        self.startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
    }
}

public struct PostablePage: Codable, Hashable, Sendable {
    public var list: [PostableSchedule]

    public init(list: [PostableSchedule] = []) { self.list = list }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try c.decodeIfPresent([PostableSchedule].self, forKey: .list) ?? []
    }
}

/// `POST`/`DELETE /plan/feed/{id}/vote` 응답.
public struct FeedVoteResult: Codable, Hashable, Sendable {
    public var myVote: String?
    public var helpfulCount: Int

    public init(myVote: String? = nil, helpfulCount: Int = 0) {
        self.myVote = myVote
        self.helpfulCount = helpfulCount
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.myVote = try c.decodeIfPresent(String.self, forKey: .myVote)
        self.helpfulCount = try c.decodeIfPresent(Int.self, forKey: .helpfulCount) ?? 0
    }
}

/// 같은 카테고리 안에서의 시세. `GET /plan/feed/stats`
///
/// **평균이 아니라 중앙값·사분위수다.** 자기 신고 금액이라 단위를 잘못 적은 한 건이
/// 평균을 통째로 흔든다. 표본 수를 함께 주는 이유는 **적으면 아예 안 보여주기
/// 위해서**다 — 3개로 시세를 말하는 건 조작보다 큰 거짓말이다.
///
/// 표본이 적은 카테고리는 **서버가 아예 안 내려 준다**(`MIN_STATS_SAMPLE` = 5).
/// 화면에서 다시 세지 말고 받은 것만 그린다.
public struct FeedCategoryStats: Codable, Hashable, Sendable {
    public var categoryName: String
    public var sampleCount: Int
    public var median: Double
    public var p25: Double
    public var p75: Double

    public init(
        categoryName: String = "",
        sampleCount: Int = 0,
        median: Double = 0,
        p25: Double = 0,
        p75: Double = 0
    ) {
        self.categoryName = categoryName
        self.sampleCount = sampleCount
        self.median = median
        self.p25 = p25
        self.p75 = p75
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.sampleCount = try c.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0
        self.median = try c.decode(LooseDouble.self, forKey: .median).wrappedValue ?? 0
        self.p25 = try c.decode(LooseDouble.self, forKey: .p25).wrappedValue ?? 0
        self.p75 = try c.decode(LooseDouble.self, forKey: .p75).wrappedValue ?? 0
    }
}

/// `POST /plan/feed` 요청 바디 — 완료한 일정에 별점과 한 줄을 얹는다.
///
/// **장소는 필수가 아니다.** 청첩장·예물·신혼여행처럼 지도에 없는 게 정상인
/// 카테고리가 있고, 막으면 공급이 죽는다. 없으면 장소 관련 키를 통째로 뺀다.
public struct FeedPostRequest: Codable, Hashable, Sendable {
    public var scheduleId: Int
    /// 만족도 1~5
    public var rating: Int
    /// 비우면 보내지 않는다 — **별점만 있는 후기가 정상이다.**
    public var body: String?
    public var isAmountPublic: Bool
    /// `"GROOM"` | `"BRIDE"`
    public var authorRole: String

    /// 카카오 장소 id. **같은 업체 후기를 묶는 유일한 열쇠**다.
    ///
    /// - Important: **빈 문자열을 보내지 말 것.** 그게 하나의 "업체" 가 되어 서로
    ///   다른 곳이 묶인다.
    public var placeId: String?
    /// 고른 장소 이름. **이것이 일정 제목을 이긴다.**
    public var placeName: String?
    /// 도로명 주소. `region` 은 백엔드가 여기서 잘라 만든다 —
    /// **일정의 `location` 을 넘기지 말 것**(그건 주소가 아니라 업체명이다).
    public var address: String?
    public var lat: Double?
    public var lng: Double?
    /// 올린 사진 키(`POST /plan/feed/image` 로 받은 자리) — 순서가 곧 보여 주는 순서. 없으면 키를 뺀다.
    public var images: [String]

    public init(
        scheduleId: Int,
        rating: Int,
        body: String? = nil,
        isAmountPublic: Bool,
        authorRole: String,
        placeId: String? = nil,
        placeName: String? = nil,
        address: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        images: [String] = []
    ) {
        self.scheduleId = scheduleId
        self.images = images
        self.rating = rating
        let trimmed = body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.body = trimmed.isEmpty ? nil : trimmed
        self.isAmountPublic = isAmountPublic
        self.authorRole = authorRole

        // 장소를 안 고른 후기에는 장소 키를 하나도 싣지 않는다.
        let name = placeName?.trimmingCharacters(in: .whitespaces) ?? ""
        if name.isEmpty {
            self.placeId = nil
            self.placeName = nil
            self.address = nil
            self.lat = nil
            self.lng = nil
        } else {
            let id = placeId?.trimmingCharacters(in: .whitespaces) ?? ""
            self.placeId = id.isEmpty ? nil : id
            self.placeName = name
            self.address = address
            self.lat = lat
            self.lng = lng
        }
    }

    /// 합성 인코딩은 `nil` 인 키를 통째로 생략한다 — 여기서는 그게 맞다.
    /// 빈 문자열을 보내면 `placeId` 가 가짜 업체를 하나 만든다.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(scheduleId, forKey: .scheduleId)
        try c.encode(rating, forKey: .rating)
        try c.encodeIfPresent(body, forKey: .body)
        try c.encode(isAmountPublic, forKey: .isAmountPublic)
        try c.encode(authorRole, forKey: .authorRole)
        try c.encodeIfPresent(placeId, forKey: .placeId)
        try c.encodeIfPresent(placeName, forKey: .placeName)
        try c.encodeIfPresent(address, forKey: .address)
        try c.encodeIfPresent(lat, forKey: .lat)
        try c.encodeIfPresent(lng, forKey: .lng)
        if !images.isEmpty { try c.encode(images, forKey: .images) }
    }
}

/// `GET /plan/feed/categories` 한 줄 — 공개 후기가 있는 카테고리와 그 수(웹 `lib/feedCategories.ts`).
/// `count` 는 서버가 순서를 정하는 데만 쓴다 — **칩에 숫자를 붙이지 않는다.**
public struct FeedCategoryCount: Codable, Hashable, Sendable {
    public var categoryName: String
    public var count: Int

    public init(categoryName: String = "", count: Int = 0) {
        self.categoryName = categoryName
        self.count = count
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

public struct FeedCategoryCountPage: Codable, Hashable, Sendable {
    public var total: Int
    public var list: [FeedCategoryCount]

    public init(total: Int = 0, list: [FeedCategoryCount] = []) {
        self.total = total
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try c.decodeIfPresent([FeedCategoryCount].self, forKey: .list) ?? []
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? self.list.count
    }
}

/// `POST /plan/feed/image` 응답 — 사진 한 장의 자리. `uploadUrl` 은 10분, `key` 는 24시간 안에 후기에 써야 한다.
public struct FeedImageUpload: Codable, Hashable, Sendable {
    public var key: String
    public var uploadUrl: String

    public init(key: String = "", uploadUrl: String = "") {
        self.key = key
        self.uploadUrl = uploadUrl
    }
}

/// 후기의 업체 — 고치기에서 처음 값과 비교해 바뀌었을 때만 보낸다(안드로이드 `domain/FeedEdit.kt` 의 `FeedPlace`).
public struct FeedPlace: Codable, Hashable, Sendable {
    /// 좌표로만 찾은 경우 없다 — **빈 문자열을 보내지 말 것**(가짜 업체 하나가 생긴다).
    public var placeId: String?
    public var placeName: String
    public var address: String
    public var lat: Double?
    public var lng: Double?

    public init(placeId: String? = nil, placeName: String, address: String, lat: Double? = nil, lng: Double? = nil) {
        self.placeId = placeId
        self.placeName = placeName
        self.address = address
        self.lat = lat
        self.lng = lng
    }

    /// 내 후기에서 — 주소나 placeId 가 있을 때만 업체가 있다.
    public init?(post: FeedPost) {
        let address = post.address?.trimmingCharacters(in: .whitespaces) ?? ""
        let id = post.placeId?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !address.isEmpty || !id.isEmpty else { return nil }
        self.init(placeId: post.placeId, placeName: post.title, address: post.address ?? "", lat: post.lat, lng: post.lng)
    }

    /// 장소 검색 결과에서 — 도로명 주소가 있으면 그것, 없으면 지번.
    public init(result: PlaceSearchResult) {
        let road = result.roadAddressName?.trimmingCharacters(in: .whitespaces) ?? ""
        self.init(placeId: result.placeId, placeName: result.placeName,
                  address: road.isEmpty ? result.addressName : road, lat: result.lat, lng: result.lng)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let placeId, !placeId.trimmingCharacters(in: .whitespaces).isEmpty { try c.encode(placeId, forKey: .placeId) }
        try c.encode(placeName, forKey: .placeName)
        try c.encode(address, forKey: .address)
        try c.encodeIfPresent(lat, forKey: .lat)
        try c.encodeIfPresent(lng, forKey: .lng)
    }
}

/// `PATCH /plan/feed/{id}` 본문 — **보낸 필드만 바뀌고 빠진 필드는 그대로**다.
///
/// - 업체: 안 바꿨으면 키를 빼고(`.unchanged`), 뗐으면 `null`, 다시 골랐으면 객체.
/// - 사진: 건드렸을 때만 `images`(남길 키 전체) + `baseImages`(연 순간의 키)를 함께 보낸다 — 별점만 고쳤는데 연 순간의
///   목록을 보내면 그사이 다른 기기에서 더한 사진이 "뺀 사진" 이 되어 지워진다.
/// - 카테고리 · 금액은 일정에서 옮긴 값이라 보내지 않는다(서버도 받지 않는다).
public struct FeedEditRequest: Encodable, Hashable, Sendable {
    public enum PlaceChange: Hashable, Sendable { case unchanged, cleared, set(FeedPlace) }

    public var rating: Int
    public var body: String
    public var isAmountPublic: Bool
    public var authorRole: String
    public var place: PlaceChange
    /// `nil` 이면 사진을 건드리지 않았다
    public var images: (keep: [String], base: [String])?

    public init(rating: Int, body: String, isAmountPublic: Bool, authorRole: String,
                place: PlaceChange = .unchanged, images: (keep: [String], base: [String])? = nil) {
        self.rating = rating
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isAmountPublic = isAmountPublic
        self.authorRole = authorRole
        self.place = place
        self.images = images
    }

    private enum CodingKeys: String, CodingKey { case rating, body, isAmountPublic, authorRole, place, images, baseImages }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rating, forKey: .rating)
        // 빈 문자열 "" 이면 서버가 한 줄을 지운다 — 고치기에서 비웠으면 그게 맞다
        try c.encode(body, forKey: .body)
        try c.encode(isAmountPublic, forKey: .isAmountPublic)
        try c.encode(authorRole, forKey: .authorRole)
        switch place {
        case .unchanged: break
        case .cleared: try c.encodeNil(forKey: .place)
        case .set(let value): try c.encode(value, forKey: .place)
        }
        if let images {
            try c.encode(images.keep, forKey: .images)
            try c.encode(images.base, forKey: .baseImages)
        }
    }

    public static func == (lhs: FeedEditRequest, rhs: FeedEditRequest) -> Bool {
        lhs.rating == rhs.rating && lhs.body == rhs.body && lhs.isAmountPublic == rhs.isAmountPublic
            && lhs.authorRole == rhs.authorRole && lhs.place == rhs.place
            && lhs.images?.keep == rhs.images?.keep && lhs.images?.base == rhs.images?.base
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rating); hasher.combine(body); hasher.combine(isAmountPublic); hasher.combine(authorRole)
        hasher.combine(place); hasher.combine(images?.keep); hasher.combine(images?.base)
    }
}
