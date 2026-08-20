import Foundation

/// `GET /plan/schedule/calendar` 응답의 `data.list` 항목 — 하루치 묶음.
public struct CalendarDay: Codable, Hashable, Sendable, Identifiable {
    /// "YYYY-MM-DD"
    public var day: String
    public var list: [CalendarPlanItem]

    public var id: String { day }

    public init(day: String = "", list: [CalendarPlanItem] = []) {
        self.day = day
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.day = try container.decodeIfPresent(String.self, forKey: .day) ?? ""
        self.list = try container.decodeIfPresent([CalendarPlanItem].self, forKey: .list) ?? []
    }
}

/// 달력 칸에 표시할 플랜.
///
/// - Important: 백엔드는 현재 `id` 와 `title` 만 준다. 그래도 `status` / `categoryName` 을
///   받아 두는 이유는, 필드가 추가되는 순간 완료 취소선·카테고리 표시가 그대로 살아나야 하기
///   때문이다. **status 를 버리면 완료 표시가 영영 안 뜬다** (안드로이드도 같은 주석을 달아뒀다).
public struct CalendarPlanItem: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    public var title: String
    public var categoryName: String
    @LooseInt public var amount: Int?
    public var status: ScheduleStatus?

    public var isCompleted: Bool { status?.isCompleted ?? false }

    public init(
        id: Int = 0,
        title: String = "",
        categoryName: String = "",
        amount: Int? = nil,
        status: ScheduleStatus? = nil
    ) {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self._amount = LooseInt(wrappedValue: amount)
        self.status = status
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self._amount = try container.decodeIfPresent(LooseInt.self, forKey: .amount)
            ?? LooseInt(wrappedValue: nil)
        self.status = try container.decodeIfPresent(ScheduleStatus.self, forKey: .status)
    }
}

public struct CalendarPage: Codable, Hashable, Sendable {
    public var list: [CalendarDay]

    public init(list: [CalendarDay] = []) {
        self.list = list
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.list = try container.decodeIfPresent([CalendarDay].self, forKey: .list) ?? []
    }
}
