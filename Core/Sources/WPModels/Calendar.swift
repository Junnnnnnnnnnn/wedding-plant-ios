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
    @LooseDouble public var amount: Double?
    public var status: ScheduleStatus?
    /// 시각 `"HH:mm"`. 그날 목록 카드에서 `오전 11:00` 으로 보인다(안드로이드 `CalendarPlanItem.startTime`).
    public var startTime: String?
    /// 결제 원값. **직접 읽지 말 것** — 판단은 `isPaid`(SchedulePayable).
    /// 달 머리 면의 "지출/예정" 합계와 그날 목록의 `결제함` 표가 이 값을 본다.
    public var isPaidRaw: Bool?

    public var isCompleted: Bool { status?.isCompleted ?? false }

    /// 저장 이름이 `isPaidRaw` 라 합성 키로는 백엔드의 `isPaid` 를 못 읽는다.
    enum CodingKeys: String, CodingKey {
        case id, title, categoryName, amount, status, startTime
        case isPaidRaw = "isPaid"
    }

    public init(
        id: Int = 0,
        title: String = "",
        categoryName: String = "",
        amount: Double? = nil,
        status: ScheduleStatus? = nil,
        startTime: String? = nil,
        isPaidRaw: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self._amount = LooseDouble(wrappedValue: amount)
        self.status = status
        self.startTime = startTime
        self.isPaidRaw = isPaidRaw
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        self._amount = try container.decodeIfPresent(LooseDouble.self, forKey: .amount)
            ?? LooseDouble(wrappedValue: nil)
        self.status = try container.decodeIfPresent(ScheduleStatus.self, forKey: .status)
        self.startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        self.isPaidRaw = try container.decodeIfPresent(Bool.self, forKey: .isPaidRaw)
    }
}

extension CalendarPlanItem: SchedulePayable {
    public var statusRawValue: String? { status?.rawValue }
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
