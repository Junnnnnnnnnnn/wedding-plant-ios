import Foundation
import WPModels

/// 자랑하기 상세의 묶음·소계.
///
/// **묶는 일과 소계는 프론트가 한다** — 서버에 두면 문구 하나 고치는 데 백엔드
/// 배포가 묶인다. 응답은 평평한 `items` 다.
public enum BragRules {

    /// 카테고리 한 묶음.
    public struct Group: Hashable, Sendable, Identifiable {
        public var categoryName: String
        public var items: [BragPlanItem]
        /// **지출과 예정을 함께 센다** (완료 185 + 예정 35 = 220).
        public var subtotal: Int
        /// 왼쪽 범례와 같은 색을 쓰기 위한 자리. `nil` 이면 무채색이다.
        public var colorIndex: Int?

        public var id: String { categoryName }
    }

    /// 색이 붙는 카테고리 수.
    ///
    /// **`STACK_COLORS` 를 `i % 4` 로 돌리지 말 것.** 서버는 카테고리를 전부
    /// 내려주는데 그러면 다섯 번째가 첫 번째와 같은 분홍이 된다(실제로 "청첩장"
    /// 이 "예식장" 과 같은 색으로 나왔다).
    public static let coloredCount = 4

    /// `그 외` 묶음의 이름. 상위 4개 밖을 여기로 합친다 —
    /// **그냥 빼면 막대가 실제 지출보다 짧아진다.**
    public static let othersLabel = "그 외"

    /// 평평한 목록을 카테고리로 묶는다.
    ///
    /// **왼쪽 범례 색과 오른쪽 묶음 머리 색이 같아야 한다.** "이 1,240만원이 이 두
    /// 장이다" 가 눈으로 붙는 것이 이 화면의 전부다. 그래서 묶음 순서를
    /// `categoryChart`(지출 큰 순)에 맞추고, 색은 그 순서의 앞 4개에만 준다.
    public static func groups(
        items: [BragPlanItem],
        chart: [BragChartItem]
    ) -> [Group] {
        var buckets: [String: [BragPlanItem]] = [:]
        for item in items {
            let key = item.categoryName.isEmpty ? othersLabel : item.categoryName
            buckets[key, default: []].append(item)
        }

        // 차트 순서(지출 큰 순)를 먼저 쓰고, 차트에 없는 카테고리는 뒤에 붙인다.
        var ordered = chart.map(\.categoryName).filter { buckets[$0] != nil }
        for key in buckets.keys.sorted() where !ordered.contains(key) {
            ordered.append(key)
        }

        return ordered.enumerated().map { index, name in
            let group = buckets[name] ?? []
            return Group(
                categoryName: name,
                items: group,
                subtotal: group.reduce(0) { $0 + ($1.amount ?? 0) },
                colorIndex: index < coloredCount ? index : nil
            )
        }
    }

    /// 한 플랜이 그 카테고리 소계에서 차지하는 몫(%).
    ///
    /// **카테고리에 플랜이 하나뿐이면 몫을 말하지 않는다** — 늘 100% 라
    /// "180만 원 가운데 100%" 처럼 같은 말을 두 번 하는 문장이 된다.
    /// 그때는 "이 플랜 하나뿐" 이라고 적는다.
    public static func sharePercent(item: BragPlanItem, in group: Group) -> Int? {
        guard group.items.count > 1, group.subtotal > 0 else { return nil }
        let amount = item.amount ?? 0
        return Int((Double(amount) / Double(group.subtotal) * 100).rounded())
    }

    /// 지도를 못 내는 이유. **둘을 갈라 적는다** —
    /// 줄이나 상자가 사라지면 "안 적었나" 와 "화면이 안 그렸나" 를 구별할 수 없다.
    public enum MapAbsence: Hashable, Sendable {
        /// 장소가 아예 없다.
        case noPlace
        /// 장소는 있는데 좌표가 없다(해외 등).
        case noCoordinates

        public var message: String {
            switch self {
            case .noPlace: return "장소를 등록하지 않은 일정이에요"
            case .noCoordinates: return "지도에 표시할 수 없는 장소예요"
            }
        }
    }

    /// 지도를 낼 수 있으면 `nil`, 못 내면 그 이유.
    ///
    /// **상세 시트는 빈 자리를 두지 않는다.** 피드의 목록 카드는 장소가 없으면 줄을
    /// 지우지만(금액을 세로로 훑는 설계라), 이 시트는 한 장을 자세히 보는 자리라
    /// **"없다" 는 것도 정보다.**
    public static func mapAbsence(for item: BragPlanItem) -> MapAbsence? {
        let place = item.location?.trimmingCharacters(in: .whitespaces) ?? ""
        if place.isEmpty { return .noPlace }
        return item.hasCoordinates ? nil : .noCoordinates
    }

    /// 좋아요를 누른 뒤의 상태. **낙관적으로** 그리고 실패하면 되돌린다.
    public static func applyLike(liked: Bool, likeCount: Int) -> (liked: Bool, likeCount: Int) {
        liked ? (false, max(0, likeCount - 1)) : (true, likeCount + 1)
    }
}
