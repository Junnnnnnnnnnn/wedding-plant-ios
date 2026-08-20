import Foundation

/// 일정 진행 상태. 알 수 없는 값이 와도 디코딩이 깨지지 않도록 RawRepresentable 구조체.
public struct ScheduleStatus: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // 합성 Codable은 `{"rawValue":"COMPLETED"}` 로 인코딩해버리므로 직접 단일 값으로 처리한다.
    public init(from decoder: any Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let planned = ScheduleStatus(rawValue: "PLANNED")
    public static let completed = ScheduleStatus(rawValue: "COMPLETED")

    public var isCompleted: Bool { self == .completed }
}

/// 결제 유형.
public struct PayType: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let other = PayType(rawValue: "OTHER")
}

/// 일정 항목.
///
/// 웹의 `ScheduleListItem`(main/calendar/budget-detail) 과 `GuestScheduleItem`(lib/guestSchedule.ts)을
/// 하나로 합친 모델. 리스트 응답에는 일부 필드가 빠져 오므로 대부분 optional 이다.
public struct ScheduleItem: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var categoryName: String
    public var title: String
    public var amount: Int?
    /// "YYYY-MM-DD"
    public var startDate: String?
    /// 등록일 (ISO 문자열)
    public var createDate: String?
    public var status: ScheduleStatus?
    public var location: String?
    public var locationLat: Double?
    public var locationLng: Double?
    public var memo: String?
    public var payType: PayType?
    public var addCategoryNameList: [String]?

    /// 게스트(비로그인) 로컬 항목 여부.
    ///
    /// 웹은 `_guest: true` 마커와 음수 id 를 함께 썼다. iOS 로컬 저장소에서도 동일하게
    /// **음수 id = 로컬 전용** 규칙을 유지한다(백엔드는 양수 id만 발급).
    public var isGuest: Bool { id < 0 }

    public init(
        id: Int,
        categoryName: String,
        title: String,
        amount: Int? = nil,
        startDate: String? = nil,
        createDate: String? = nil,
        status: ScheduleStatus? = nil,
        location: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil,
        memo: String? = nil,
        payType: PayType? = nil,
        addCategoryNameList: [String]? = nil
    ) {
        self.id = id
        self.categoryName = categoryName
        self.title = title
        self.amount = amount
        self.startDate = startDate
        self.createDate = createDate
        self.status = status
        self.location = location
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.memo = memo
        self.payType = payType
        self.addCategoryNameList = addCategoryNameList
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        // 금액은 소수로 내려올 수 있다. Int 로 바로 받으면 항목 하나가 리스트 전체를 깨뜨린다.
        self.amount = try container.decode(LooseInt.self, forKey: .amount).wrappedValue
        self.startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        self.createDate = try container.decodeIfPresent(String.self, forKey: .createDate)
        self.status = try container.decodeIfPresent(ScheduleStatus.self, forKey: .status)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.locationLat = try container.decodeIfPresent(Double.self, forKey: .locationLat)
        self.locationLng = try container.decodeIfPresent(Double.self, forKey: .locationLng)
        self.memo = try container.decodeIfPresent(String.self, forKey: .memo)
        self.payType = try container.decodeIfPresent(PayType.self, forKey: .payType)
        self.addCategoryNameList = try container.decodeIfPresent([String].self, forKey: .addCategoryNameList)
    }
}

/// `GET /plan/schedule/list` 응답 페이로드.
///
/// 배열이 아니라 `{ total, list }` 래퍼다.
public struct SchedulePage: Codable, Hashable, Sendable {
    public var total: Int
    public var list: [ScheduleItem]

    public init(total: Int, list: [ScheduleItem] = []) {
        self.total = total
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([ScheduleItem].self, forKey: .list) ?? []
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? self.list.count
    }
}

/// `POST /plan/schedule` / `PATCH /plan/schedule/{id}` 요청 바디.
///
/// 웹 `KakaoLoginAlert` 의 게스트 일정 마이그레이션 바디와 동일한 형태를 유지한다.
public struct ScheduleWriteRequest: Codable, Hashable, Sendable {
    public var categoryName: String
    public var title: String
    public var payType: String
    public var amount: Int
    /// "YYYY-MM-DD". `nil` 이면 **명시적 null 로 직렬화**된다.
    ///
    /// 날짜를 "미정" 으로 되돌리려면 `PATCH` 에서 키를 빼면 안 되고 `null` 을 보내야 한다.
    /// 키를 생략하면 백엔드가 "변경 없음" 으로 처리해 기존 날짜가 그대로 남는다.
    public var startDate: String?
    public var location: String
    public var locationLat: Double
    public var locationLng: Double
    public var memo: String
    /// **생성(POST)에는 반드시 넣어야 한다.**
    ///
    /// 메인 화면은 `/plan/schedule/room/{roomId}/list` 를 읽는다. `roomId` 를 빼면
    /// 개인 스코프로 저장되어 **200 으로 성공하는데 목록에는 영영 안 나타난다.**
    /// 값은 `GET /plan/user` 응답의 `roomId` 를 쓴다. 수정(PATCH)에는 붙이지 않는다.
    public var roomId: Int?
    public var addCategoryNameList: [String]?

    public init(
        categoryName: String,
        title: String,
        payType: String = PayType.other.rawValue,
        amount: Int = 0,
        startDate: String?,
        location: String = "",
        locationLat: Double = 0,
        locationLng: Double = 0,
        memo: String = "",
        roomId: Int? = nil,
        addCategoryNameList: [String]? = nil
    ) {
        self.categoryName = categoryName
        self.title = title
        self.payType = payType
        self.amount = amount
        self.startDate = startDate
        self.location = location
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.memo = memo
        self.roomId = roomId
        self.addCategoryNameList = addCategoryNameList
    }

    /// 합성 인코딩은 `Optional` 이 nil 이면 **키를 통째로 생략**한다.
    /// 그런데 백엔드는 `startDate` 키가 없으면 "변경 없음" 으로 처리하므로,
    /// 날짜를 "미정" 으로 되돌리려면 **명시적 `null`** 을 보내야 한다. 그래서 직접 구현한다.
    ///
    /// 반대로 `roomId`·`addCategoryNameList` 는 없을 때 **키가 빠져야** 한다
    /// (수정 요청에 `roomId` 를 붙이면 안 되므로).
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(categoryName, forKey: .categoryName)
        try container.encode(title, forKey: .title)
        try container.encode(payType, forKey: .payType)
        try container.encode(amount, forKey: .amount)
        try container.encode(location, forKey: .location)
        try container.encode(locationLat, forKey: .locationLat)
        try container.encode(locationLng, forKey: .locationLng)
        try container.encode(memo, forKey: .memo)

        if let startDate {
            try container.encode(startDate, forKey: .startDate)
        } else {
            try container.encodeNil(forKey: .startDate)
        }

        try container.encodeIfPresent(roomId, forKey: .roomId)
        try container.encodeIfPresent(addCategoryNameList, forKey: .addCategoryNameList)
    }

    /// 로컬 게스트 일정을 백엔드 등록 바디로 변환한다.
    ///
    /// 웹의 마이그레이션 로직과 동일하게 빈 `startDate` 는 `fallbackStartDate` 로 대체하고,
    /// 비어 있는 `addCategoryNameList` 는 아예 전송하지 않는다.
    public init(guestItem item: ScheduleItem, fallbackStartDate: String, roomId: Int? = nil) {
        let trimmedStart = item.startDate?.trimmingCharacters(in: .whitespaces) ?? ""
        let categories = item.addCategoryNameList ?? []
        self.init(
            categoryName: item.categoryName,
            title: item.title,
            payType: item.payType?.rawValue ?? PayType.other.rawValue,
            amount: item.amount ?? 0,
            startDate: trimmedStart.isEmpty ? fallbackStartDate : trimmedStart,
            location: item.location ?? "",
            locationLat: item.locationLat ?? 0,
            locationLng: item.locationLng ?? 0,
            memo: item.memo ?? "",
            roomId: roomId,
            addCategoryNameList: categories.isEmpty ? nil : categories
        )
    }
}

/// `POST /plan/setting` 요청 바디 (예산·이름·결혼일 + 약관 동의).
public struct PlanSettingRequest: Codable, Hashable, Sendable {
    /// "YYYY-MM-DD"
    public var weddingDate: String
    public var budget: Int
    public var name: String
    public var requiredAgreementDate: String?
    public var adAgreementDate: String?

    public init(
        weddingDate: String,
        budget: Int,
        name: String,
        requiredAgreementDate: String? = nil,
        adAgreementDate: String? = nil
    ) {
        self.weddingDate = weddingDate
        self.budget = budget
        self.name = name
        self.requiredAgreementDate = requiredAgreementDate
        self.adAgreementDate = adAgreementDate
    }
}
