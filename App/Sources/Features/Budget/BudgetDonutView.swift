import SwiftUI
import WPDomain
import WPUtils

/// 예산 구성 도넛 — 웹 `app/budget-detail/components/BudgetDonut.tsx` 이식.
///
/// 계산은 전부 `BudgetDonutSegments`(Core)가 하고 여기서는 그리기만 한다.
/// 왜 분모가 자본이 아닌지, 눈금이 왜 필요한지는 그쪽 주석에 있다.
///
/// 색의 뜻은 홈 대시보드의 막대와 같다 —
/// 분홍=실제로 나간 돈, 빨강=자본 초과, 회색=아직 안 쓴 예정, 트랙=여유.
struct BudgetDonutView: View {
    var segments: BudgetDonutSegments

    /// 웹 `h-[190px] w-[190px]`
    private let size: CGFloat = 190

    var body: some View {
        // 폰에서는 카드를 두르지 않는다(시안 C안 05) — 도넛 하나뿐인 카드는
        // 테두리만 한 겹 더 그릴 뿐이고, 그 여백이 그대로 스크롤이 된다.
        VStack(spacing: 0) {
            ring
            Spacer().frame(height: 20)
            legend
            Spacer().frame(height: 20)
            summaryRows
            if segments.remaining < 0 {
                Spacer().frame(height: 16)
                overWarning
            }
        }
        .padding(.top, 20)
    }

    // MARK: - 고리

    private var ring: some View {
        ZStack {
            // 트랙 = 여유
            circle(color: Color(hex: 0xF4EFF2), from: 0, to: 100)

            ForEach(arcs, id: \.key) { arc in
                circle(color: arc.color, from: arc.from, to: arc.from + arc.len)
            }

            // 자본 눈금. **흰 틈을 먼저 내고 그 위에 검은 선을 얹는다** —
            // 선만 그리면 색 경계에 묻혀 렌더링 티처럼 보인다.
            if let mark = segments.capitalMark {
                circle(color: .white, from: mark - 1, to: mark + 1)
                circle(color: WPColor.textPrimary, from: mark - 0.4, to: mark + 0.4)
            }

            center
        }
        .frame(width: size, height: size)
    }

    private struct Arc {
        var key: String
        var from: Double
        var len: Double
        var color: Color
    }

    /// 웹과 같은 순서로 쌓는다 — 사용 → 초과 → 예정.
    private var arcs: [Arc] {
        var out: [Arc] = []
        var cursor: Double = 0
        func push(_ key: String, _ value: Int, _ color: Color) {
            let len = segments.ratio(value)
            guard len > 0 else { return }
            out.append(Arc(key: key, from: cursor, len: len, color: color))
            cursor += len
        }
        push("used", segments.withinCapital, WPColor.primary)
        push("over", segments.overUsed, Self.overColor)
        push("planned", segments.planned, Self.plannedColor)
        return out
    }

    /// 웹 SVG 는 `viewBox 42` · `r 15.9` · `strokeWidth 6` 이다. 비율로 옮긴다.
    private var lineWidth: CGFloat { size * 6 / 42 }
    private var inset: CGFloat { size * (42 - 31.8) / 42 / 2 }

    private func circle(color: Color, from: Double, to: Double) -> some View {
        Circle()
            .trim(from: max(0, from) / 100, to: min(100, to) / 100)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth))
            .padding(inset)
            // 웹 `-rotate-90` — 12시에서 시작한다.
            .rotationEffect(.degrees(-90))
    }

    private var center: some View {
        VStack(spacing: 2) {
            Text("남은 금액")
                .font(WPFont.hak(12))
                .foregroundStyle(WPColor.fgMuted)
            Text(withThousands(segments.remaining))
                .font(WPFont.tmoney(32, .bold))
                .tracking(-0.04 * 32)
                .foregroundStyle(segments.remaining < 0 ? Self.overColor : WPColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("만 원")
                .font(WPFont.hak(12))
                .foregroundStyle(WPColor.fgSubtle)
        }
        .padding(.horizontal, 30)
    }

    // MARK: - 범례

    private var legend: some View {
        // 넘긴 경우 분홍 구간은 "사용 전체" 가 아니라 자본까지다. 그냥 "사용" 이라
        // 쓰면 옆 표의 합과 어긋나 보여서 이름을 나눈다.
        FlowRow(spacing: 16, lineSpacing: 8, alignment: .center) {
            legendItem(
                color: WPColor.primary,
                text: "\(segments.used > segments.capital ? "자본 내 사용" : "사용") \(withThousands(segments.withinCapital))"
            )
            if segments.used > segments.capital {
                legendItem(
                    color: Self.overColor,
                    text: "자본 초과 \(withThousands(segments.overUsed))"
                )
            }
            if segments.capitalMark != nil {
                legendItem(color: WPColor.textPrimary, text: "초기 자본", isTick: true)
            }
            if segments.planned > 0 {
                legendItem(
                    color: Self.plannedColor,
                    text: "예정 \(withThousands(segments.planned))"
                )
            }
            // 남은 트랙에도 이름을 준다 — 세 조각의 합이 자본이라는 게 보인다.
            if segments.remaining > 0 {
                legendItem(
                    color: Color(hex: 0xF4EFF2),
                    text: "여유 \(withThousands(segments.remaining))"
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func legendItem(color: Color, text: String, isTick: Bool = false) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: isTick ? 1 : 3, style: .continuous)
                .fill(color)
                .frame(width: isTick ? 3 : 10, height: isTick ? 12 : 10)
            Text(text)
                .font(WPFont.hak(13))
                .foregroundStyle(WPColor.fgMuted)
        }
    }

    // MARK: - 요약 두 줄

    /// 폰(시안 C안 05)은 구분선 행 둘이다.
    ///
    /// **초기 자본은 머리 면이 이미 말하고 있어 여기서 다시 세지 않는다.**
    /// `사용 후 잔액`(자본-사용)은 도넛의 분홍 구간 밖 전부라, 가운데
    /// `남은 금액`(자본-예정-사용)과 같은 그림의 다른 구간이다 —
    /// **예전처럼 물음표 툴팁으로 해명할 필요가 없는 이유다.**
    private var summaryRows: some View {
        VStack(spacing: 0) {
            summaryRow(
                label: "사용률",
                value: "\(segments.usedPercent)%",
                valueColor: segments.usedPercent > 100 ? Self.overColor : WPColor.fgNeutral
            )
            summaryRow(
                label: "사용 후 잔액",
                value: "\(withThousands(segments.savings))만 원",
                valueColor: WPColor.fgNeutral
            )
        }
        .padding(.horizontal, 16)
    }

    private func summaryRow(label: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(WPFont.hak(14))
                    .foregroundStyle(WPColor.fgMuted)
                Spacer(minLength: 8)
                Text(value)
                    .font(WPFont.tmoney(14, .bold))
                    .foregroundStyle(valueColor)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - 넘겼을 때의 문장

    /// 예산을 넘겼을 때만 문장으로 한 번 더 말한다.
    private var overWarning: some View {
        Text(overWarningText)
            .font(WPFont.hak(12.5))
            .lineSpacing(5)
            .foregroundStyle(Color(hex: 0x8A3236))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color(hex: 0xFFF5F5),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Self.overColor.opacity(0.13), lineWidth: 1)
            )
            .padding(.horizontal, 16)
    }

    private var overWarningText: String {
        var text = "자본보다 \(withThousands(abs(segments.remaining)))만원이 모자랍니다"
        if segments.used > segments.capital {
            text += " — 이미 \(withThousands(segments.overUsed))만원을 더 썼고,"
            text += " 예정 \(withThousands(segments.planned))만원이 남아 있습니다"
        }
        return text + "."
    }

    // MARK: - 색

    /// 웹 `#e5484d` — 자본 초과.
    static let overColor = Color(hex: 0xE5484D)
    /// 웹 `#cdbfc7` — 아직 안 쓴 예정.
    static let plannedColor = Color(hex: 0xCDBFC7)
}
