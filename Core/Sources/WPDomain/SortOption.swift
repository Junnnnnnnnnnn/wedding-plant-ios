import Foundation

/// 플랜 목록 정렬 선택지. 안드로이드 `MainViewModel.SortOption` 과 **라벨까지 동일**해야 한다.
///
/// 정렬은 클라이언트가 아니라 백엔드가 한다(`sortColumn`/`sort` 쿼리). 다만 응답 안에서
/// 날짜 미정 항목을 뒤로 미는 보정은 `ScheduleSort` 가 맡는다.
public enum SortOption: String, Sendable, CaseIterable, Identifiable {
    case priceAsc
    case priceDesc
    case dateAsc
    case dateDesc
    case nameAsc
    case nameDesc

    public var id: String { rawValue }

    /// 정렬 버튼에 짧게 표시
    public var buttonLabel: String {
        switch self {
        case .priceAsc, .priceDesc: return "가격"
        case .dateAsc, .dateDesc: return "시작"
        case .nameAsc, .nameDesc: return "제목"
        }
    }

    /// 시트 목록에 길게 표시
    public var sheetLabel: String {
        switch self {
        case .priceAsc: return "낮은 가격순"
        case .priceDesc: return "높은 가격순"
        case .dateAsc: return "플랜 시작일 오래된순"
        case .dateDesc: return "플랜 시작일 최신순"
        case .nameAsc: return "제목 가나다순"
        case .nameDesc: return "제목 가나다역순"
        }
    }

    public var column: ScheduleSort.Column {
        switch self {
        case .priceAsc, .priceDesc: return .amount
        case .dateAsc, .dateDesc: return .startDate
        case .nameAsc, .nameDesc: return .title
        }
    }

    public var descending: Bool {
        switch self {
        case .priceDesc, .dateDesc, .nameDesc: return true
        case .priceAsc, .dateAsc, .nameAsc: return false
        }
    }

    /// 웹·안드로이드 기본값
    public static let `default`: SortOption = .dateDesc
}
