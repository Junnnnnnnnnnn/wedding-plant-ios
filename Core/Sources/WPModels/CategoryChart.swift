import Foundation

/// `GET /plan/user/amount/category-chart` 응답의 항목. 단위는 만원.
public struct CategoryChartItem: Codable, Hashable, Sendable, Identifiable {
    public var categoryName: String
    /// 이 카테고리에 잡힌 전체 금액(예정 + 사용)
    @LooseInt public var totalAmount: Int?
    /// 그중 이미 쓴 금액
    @LooseInt public var usedAmount: Int?

    public var id: String { categoryName }

    public var total: Int { totalAmount ?? 0 }
    public var used: Int { usedAmount ?? 0 }

    /// 막대 채움 비율. **계획이 없는데 쓴 돈이 있으면 100%**, 둘 다 없으면 0% (웹과 동일).
    public var ratio: Double {
        if total > 0 { return min(max(Double(used) / Double(total), 0), 1) }
        return used > 0 ? 1 : 0
    }

    public init(categoryName: String = "", totalAmount: Int? = nil, usedAmount: Int? = nil) {
        self.categoryName = categoryName
        self._totalAmount = LooseInt(wrappedValue: totalAmount)
        self._usedAmount = LooseInt(wrappedValue: usedAmount)
    }
}

public struct CategoryChartPage: Codable, Hashable, Sendable {
    public var list: [CategoryChartItem]

    public init(list: [CategoryChartItem] = []) {
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([CategoryChartItem].self, forKey: .list) ?? []
    }
}
