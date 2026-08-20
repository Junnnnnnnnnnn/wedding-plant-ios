import Foundation
import WPModels
import WPUtils

/// 플랜 목록 정렬. 웹·안드로이드와 **같은 순서**가 나와야 한다.
public enum ScheduleSort {

    public enum Column: String, Sendable, CaseIterable {
        case startDate
        case amount
        case title

        /// 백엔드 `sortColumn` 파라미터 값
        public var parameter: String { rawValue }

        public var label: String {
            switch self {
            case .startDate: return "시작"
            case .amount: return "금액"
            case .title: return "이름"
            }
        }
    }

    /// 정렬한다. **날짜가 없는(미정) 항목은 정렬 방향과 무관하게 항상 맨 아래.**
    ///
    /// 웹은 `startDate ?? createDate ?? ""` 로 만든 빈 문자열이 `new Date("")` → `NaN` 이 되어,
    /// 비교 함수가 `NaN` 을 반환하면 정렬이 "같음"으로 취급해 순서가 예측 불가능해졌다.
    /// 오름차순이든 내림차순이든 미정은 뒤로 보낸다.
    public static func sorted(
        _ items: [ScheduleItem],
        by column: Column,
        descending: Bool
    ) -> [ScheduleItem] {
        // 인덱스를 함께 들고 다녀서 동점일 때 원래 순서를 유지한다(안정 정렬).
        items.enumerated().sorted { lhs, rhs in
            let a = lhs.element
            let b = rhs.element

            if column == .startDate {
                let aMissing = KstDate(dateString: a.startDate ?? "") == nil
                let bMissing = KstDate(dateString: b.startDate ?? "") == nil
                // 미정은 방향과 무관하게 뒤로
                if aMissing != bMissing { return !aMissing }
                if aMissing && bMissing { return lhs.offset < rhs.offset }
            }

            guard let comparison = compare(a, b, by: column) else {
                return lhs.offset < rhs.offset
            }
            return descending ? comparison > 0 : comparison < 0
        }
        .map(\.element)
    }

    /// 같으면 nil 을 돌려 호출부가 원래 순서를 쓰게 한다.
    private static func compare(_ a: ScheduleItem, _ b: ScheduleItem, by column: Column) -> Int? {
        switch column {
        case .startDate:
            let lhs = a.startDate ?? ""
            let rhs = b.startDate ?? ""
            return lhs == rhs ? nil : (lhs < rhs ? -1 : 1)
        case .amount:
            let lhs = a.amount ?? 0
            let rhs = b.amount ?? 0
            return lhs == rhs ? nil : (lhs < rhs ? -1 : 1)
        case .title:
            let result = a.title.compare(b.title, options: [.caseInsensitive])
            switch result {
            case .orderedSame: return nil
            case .orderedAscending: return -1
            case .orderedDescending: return 1
            }
        }
    }
}
