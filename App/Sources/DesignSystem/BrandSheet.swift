import SwiftUI

/// 웹 main 의 모바일 **C안** 공통 부품. 안드로이드 `ui/components/BrandSheet.kt` 와 짝이다.
///
/// C안 규칙 넷 (`docs/concepts/c-tokens.css`):
/// 1. 분홍 면은 **화면 맨 위 한 덩이**뿐. 본문에 분홍 면을 또 두지 않는다.
/// 2. 면에는 그 화면에서 **변하지 않는 사실**만 — 누구의 플랜인지, 언제인지, 지금 얼마인지.
/// 3. 본문의 분홍은 **누를 것**에만 — 주 버튼, 활성 탭, 선택된 칩.
/// 4. 나머지는 SEED 중립 — 회색 채움 카드와 헤어라인.

/// 웹 `bg-gradient-to-br from-[#ee2b8c] to-[#ff5c95]`
let brandGradient = LinearGradient(
    colors: [WPColor.budgetGradientStart, WPColor.budgetGradientEnd],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

/// 지금 창의 위쪽 안전 영역 높이.
///
/// 머리 면이 **스크롤 영역 안**에 있어 `safeAreaInset` 으로는 못 잡는다.
/// 폰 세로 전용 화면이라 회전으로 값이 바뀌지 않는다.
var wpStatusBarHeight: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.top }
        .first ?? 0
}

/// 분홍 머리 면.
///
/// **스크롤 영역 안에 두세요** (웹 `data-mobile-head`). 내용과 함께 올라가야 작은
/// 폰에서 목록·폼이 그만큼 더 보인다. 상태바 뒤까지 분홍이 깔리도록 인셋을 면
/// **안쪽**에서 준다. 채팅방 머리글만 예외로 고정이다.
///
/// - Parameter corner: 웹 `rounded-b-[28px]`(홈·목록) / `rounded-b-[24px]`(캘린더·상세)
struct BrandHead<Content: View>: View {
    var corner: CGFloat = 28
    var horizontal: CGFloat = 16
    var top: CGFloat = 16
    var bottom: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontal)
        .padding(.top, top + wpStatusBarHeight)
        .padding(.bottom, bottom)
        .background(brandGradient)
        .clipShape(
            .rect(
                bottomLeadingRadius: corner,
                bottomTrailingRadius: corner,
                style: .continuous
            )
        )
    }
}

/// 면 위의 원형 아이콘 버튼. 웹 `grid h-9 w-9 rounded-full text-white`
struct HeadIconButton: View {
    var systemName: String
    var label: String
    var size: CGFloat = 36
    var iconSize: CGFloat = 20
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 면 위 얇은 상자. 웹 `rounded-[12px] bg-white/20 px-4 py-3`
struct HeadInset<Content: View>: View {
    var action: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        if let action {
            Button(action: action) { box }
                .buttonStyle(.plain)
        } else {
            box
        }
    }

    private var box: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color.white.opacity(0.2),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

/// 묶음 머리글.
///
/// 웹 `flex items-baseline gap-2` + `text-[18px] font-bold`
/// + `text-[13px] text-[#868b94]` + 오른쪽 분홍 글자 버튼.
struct SectionHeader: View {
    var title: String
    var meta: String?
    var titleSize: CGFloat = 18
    var actionLabel: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(title)
                .font(WPFont.hak(titleSize, .bold))
                .tracking(-0.02 * titleSize)
                .foregroundStyle(WPColor.fgNeutral)

            if let meta, !meta.isEmpty {
                Text(meta)
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.fgSubtle)
            }

            Spacer(minLength: 8)

            if let actionLabel, let onAction {
                Button(action: onAction) {
                    Text(actionLabel)
                        .font(WPFont.hak(13, .bold))
                        .foregroundStyle(WPColor.primary)
                        .padding(2)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 카테고리 태그.
/// 웹 `rounded bg-[#fff1f7] px-1.5 py-px text-[11px] font-bold text-[#cc1873]`
struct CategoryTag: View {
    var name: String
    var done: Bool = false

    var body: some View {
        Text(name)
            .font(WPFont.hak(11, .bold))
            .foregroundStyle(done ? WPColor.fgSubtle : WPColor.brand700)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                done ? WPColor.basement : WPColor.brand100,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
    }
}

/// 구분선. 웹 `border-b border-[#0000000c]`
struct Hairline: View {
    var color: Color = WPColor.strokeSubtle

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: 1)
    }
}

/// 웹: 금액이 있으면 `14px bold #1a1c20`, 없으면 `13px #868b94` "미정"
struct AmountText: View {
    var amount: Double

    var body: some View {
        if amount > 0 {
            Text("\(withThousands(amount))만 원")
                .font(WPFont.hak(14, .bold))
                .foregroundStyle(WPColor.fgNeutral)
                .lineLimit(1)
        } else {
            Text("미정")
                .font(WPFont.hak(13))
                .foregroundStyle(WPColor.fgSubtle)
                .lineLimit(1)
        }
    }
}

/// 웹: 22pt 원, 미완료 `border-[#ffc9e0] bg-white` / 완료 `bg-[#079171]` + 흰 체크
struct CheckCircle: View {
    var checked: Bool
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(checked ? WPColor.positive : Color.white)
                Circle()
                    .strokeBorder(
                        checked ? WPColor.positive : WPColor.brand300,
                        lineWidth: 1.5
                    )
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 22, height: 22)
            // 보이는 크기는 웹·안드로이드와 같은 22pt 로 두고, 만질 곳만 44pt 로 넓힌다.
            // 바깥의 음수 패딩이 레이아웃 자리를 다시 22pt 로 되돌린다.
            .padding(11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(-11)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
        .accessibilityLabel(checked ? "예정으로 되돌리기" : "완료로 표시")
    }
}

// MARK: - 뼈대

/// 뼈대 시머. 웹 `.skeleton-shimmer` / `.skeleton-on-brand`.
///
/// **`bg-stone-50` 처럼 바탕과 거의 같은 색은 안 보인다** — 웹에서 예산 상세·참여
/// 플랜·피드의 뼈대가 그래서 받는 동안 화면이 그냥 비어 보였다. 그래서 빛을 흘린다.
/// 분홍 면 위에서는 회색이 아니라 흰 시머다(`onBrand`).
struct SkeletonBox: View {
    var width: CGFloat?
    var height: CGFloat
    var onBrand: Bool = false
    var corner: CGFloat = 4

    @State private var bright = false

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(bright ? highlight : base)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .animation(
                .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
                value: bright
            )
            .onAppear { bright = true }
            .accessibilityHidden(true)
    }

    private var base: Color {
        onBrand ? Color.white.opacity(0.2) : WPColor.basement
    }

    private var highlight: Color {
        onBrand ? Color.white.opacity(0.38) : WPColor.fillPressed
    }
}
