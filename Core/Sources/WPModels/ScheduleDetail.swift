import Foundation

/// `GET /plan/schedule/{id}` 응답 페이로드.
public struct ScheduleDetail: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var title: String
    public var categoryName: String
    public var payType: String?
    /// 만원 단위. 소수로 올 수 있어 관대하게 받는다.
    @LooseInt public var amount: Int?
    public var startDate: String?
    public var location: String?
    public var locationLat: Double?
    public var locationLng: Double?
    public var memo: String?
    public var addCategoryNameList: [String]
    /// `"NORMAL"` = 예정, `"COMPLETED"` = 완료
    public var status: String?

    public var isCompleted: Bool { status == "COMPLETED" }

    /// 웹 `PAY_TYPE_LABELS`
    public var payTypeLabel: String {
        switch payType {
        case "CASH": return "현금"
        case "CREDIT": return "카드"
        case "OTHER": return "기타"
        case nil, "": return "미정"
        default: return payType ?? "미정"
        }
    }

    /// 좌표가 없거나 (0,0) 이면 지도를 띄우지 않는다 (웹과 동일 판정).
    public var hasCoordinates: Bool {
        guard let lat = locationLat, let lng = locationLng else { return false }
        return lat != 0 || lng != 0
    }

    /// 카카오맵 앱/웹으로 여는 링크.
    public var kakaoMapURL: URL? {
        guard let location, !location.trimmingCharacters(in: .whitespaces).isEmpty,
              hasCoordinates,
              let lat = locationLat, let lng = locationLng,
              let name = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://map.kakao.com/link/map/\(name),\(lat),\(lng)")
    }

    public init(
        id: Int,
        title: String = "",
        categoryName: String = "",
        payType: String? = nil,
        amount: Int? = nil,
        startDate: String? = nil,
        location: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil,
        memo: String? = nil,
        addCategoryNameList: [String] = [],
        status: String? = nil
    ) {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self.payType = payType
        self._amount = LooseInt(wrappedValue: amount)
        self.startDate = startDate
        self.location = location
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.memo = memo
        self.addCategoryNameList = addCategoryNameList
        self.status = status
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self.payType = try container.decodeIfPresent(String.self, forKey: .payType)
        self._amount = try container.decode(LooseInt.self, forKey: .amount)
        self.startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.locationLat = try container.decodeIfPresent(Double.self, forKey: .locationLat)
        self.locationLng = try container.decodeIfPresent(Double.self, forKey: .locationLng)
        self.memo = try container.decodeIfPresent(String.self, forKey: .memo)
        self.addCategoryNameList = try container.decodeIfPresent([String].self, forKey: .addCategoryNameList) ?? []
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
    }
}
