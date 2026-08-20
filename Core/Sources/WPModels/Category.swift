import Foundation

/// `GET /plan/category/*/list` 응답의 `data.list` 항목.
public struct Category: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    public var color: String?
    /// `"SYSTEM"` | `"USER"` | `"ROOM"` — `USER` 는 선택 모달에서 my 뱃지가 붙는다.
    public var type: String?

    /// 사용자가 직접 만든 카테고리인지.
    public var isUserMade: Bool { type == "USER" }

    public init(id: Int = 0, name: String = "", color: String? = nil, type: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.type = type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
    }
}

/// 목록 응답 래퍼. `{ total, list }`
public struct CategoryPage: Codable, Hashable, Sendable {
    public var total: Int
    public var list: [Category]

    public init(total: Int = 0, list: [Category] = []) {
        self.total = total
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([Category].self, forKey: .list) ?? []
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? self.list.count
    }
}

/// `GET /plan/place/search` 결과 항목.
///
/// - Important: 이 엔드포인트는 **아직 백엔드에 없다.** 없으면 404 가 오고,
///   화면은 "장소 검색은 준비 중" 안내를 띄운다. 생기면 그대로 붙는다.
///   (카카오 REST 키를 앱에 넣지 않으려고 백엔드 프록시로 가는 설계다)
public struct PlaceSearchResult: Codable, Hashable, Sendable, Identifiable {
    public var placeName: String
    public var addressName: String
    public var roadAddressName: String?
    public var lat: Double
    public var lng: Double

    /// 좌표까지 합쳐야 유일하다. 같은 이름의 지점이 여럿일 수 있다.
    public var id: String { "\(placeName)|\(lat)|\(lng)" }

    public init(
        placeName: String = "",
        addressName: String = "",
        roadAddressName: String? = nil,
        lat: Double = 0,
        lng: Double = 0
    ) {
        self.placeName = placeName
        self.addressName = addressName
        self.roadAddressName = roadAddressName
        self.lat = lat
        self.lng = lng
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.placeName = try container.decodeIfPresent(String.self, forKey: .placeName) ?? ""
        self.addressName = try container.decodeIfPresent(String.self, forKey: .addressName) ?? ""
        self.roadAddressName = try container.decodeIfPresent(String.self, forKey: .roadAddressName)
        self.lat = try container.decodeIfPresent(Double.self, forKey: .lat) ?? 0
        self.lng = try container.decodeIfPresent(Double.self, forKey: .lng) ?? 0
    }
}

public struct PlaceSearchPage: Codable, Hashable, Sendable {
    public var total: Int
    public var list: [PlaceSearchResult]

    public init(total: Int = 0, list: [PlaceSearchResult] = []) {
        self.total = total
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([PlaceSearchResult].self, forKey: .list) ?? []
        self.total = try container.decodeIfPresent(Int.self, forKey: .total) ?? self.list.count
    }
}

/// 결제 유형. 라벨은 웹 `PAY_TYPE_LABELS` 와 동일.
public enum PlanPayType: String, Codable, Sendable, CaseIterable, Identifiable {
    case cash = "CASH"
    case credit = "CREDIT"
    case other = "OTHER"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .cash: return "현금"
        case .credit: return "카드"
        case .other: return "기타"
        }
    }

    public static func from(api value: String?) -> PlanPayType? {
        guard let value else { return nil }
        return PlanPayType(rawValue: value)
    }
}
