import SwiftUI
import WPUtils

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

private struct BrandStatusInsetKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
extension EnvironmentValues {
    var brandStatusInset: CGFloat? {
        get { self[BrandStatusInsetKey.self] }
        set { self[BrandStatusInsetKey.self] = newValue }
    }
}

/// 분홍 머리 면.
///
/// **스크롤 영역 안에 두세요** (웹 `data-mobile-head`). 내용과 함께 올라가야 작은
/// 폰에서 목록·폼이 그만큼 더 보인다. 상태바 뒤까지 분홍이 깔리도록 인셋을 면
/// **안쪽**에서 준다. 채팅방 머리글만 예외로 고정이다.
///
/// - Parameter corner: 웹 `rounded-b-[28px]`(홈·목록) / `rounded-b-[24px]`(캘린더·상세)
struct BrandHead<Content: View>: View {
    @Environment(\.brandStatusInset) private var statusInset
    var corner: CGFloat = 28
    var horizontal: CGFloat = 16
    var top: CGFloat = 16
    var bottom: CGFloat = 20
    var overhang: CGFloat = 0
    var passMember = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontal)
        .padding(.top, top + (statusInset ?? wpStatusBarHeight))
        .padding(.bottom, bottom)
        .background {
            GeometryReader { geometry in
                Group {
                    if passMember { PassMemberBackground() } else { brandGradient }
                }.frame(height: max(0, geometry.size.height - overhang))
                    .clipShape(.rect(bottomLeadingRadius: corner, bottomTrailingRadius: corner, style: .circular))
            }
        }
        // 분홍 면 위의 상태바는 흰 아이콘(안드로이드 `StatusBarIcons(dark = false)`)
        .wpLightStatusBar()
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
    /// UI 테스트가 오른쪽 글자 버튼을 찾는 이름. 같은 `추가` 가 화면마다 있어 글자로는 못 가른다.
    var actionIdentifier: String? = nil

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
                .accessibilityIdentifier(actionIdentifier ?? "")
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
                Self.animated
                    ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true)
                    : nil,
                value: bright
            )
            .onAppear { if Self.animated { bright = true } }
            .accessibilityHidden(true)
    }

    /// **UI 테스트에서는 빛을 흘리지 않는다.**
    ///
    /// XCUITest 는 앱이 idle 이 될 때까지 기다리는데 `repeatForever` 는 영원히
    /// 끝나지 않아, 관계없는 테스트가 "Failed to get matching snapshot: Timed out"
    /// 으로 죽는다(실제로 채팅 테스트가 353초 만에 그렇게 실패했다).
    ///
    /// 뼈대는 스쳐 지나가는 상태라 캡처에서 정지 상태여도 확인에 지장이 없다.
    private static let animated = !ProcessInfo.processInfo.arguments.contains("-WPDemoMode")

    private var base: Color {
        onBrand ? Color.white.opacity(0.2) : WPColor.basement
    }

    private var highlight: Color {
        onBrand ? Color.white.opacity(0.38) : WPColor.fillPressed
    }
}

/// Same 115-degree orange/pink member header and edge rings as Android.
struct PassMemberBackground: View {
    var body: some View {
        GeometryReader { g in
            LinearGradient(colors: [Color(hex: 0xF12888), Color(hex: 0xFF9355)], startPoint: UnitPoint(x: 0, y: 0.25), endPoint: UnitPoint(x: 1, y: 0.75))
                .overlay(RadialGradient(colors: [.white.opacity(0.15), .clear], center: UnitPoint(x: 0.9, y: 0.05), startRadius: 0, endRadius: max(g.size.width, g.size.height) * 0.52))
                .overlay(alignment: .topTrailing) {
                    Circle().stroke(.white.opacity(0.07), lineWidth: 23).frame(width: 157, height: 157)
                        .background(Circle().stroke(.white.opacity(0.04), lineWidth: 32).padding(-27.5))
                        .offset(x: 73.5, y: 46.5)
                }.clipped()
        }
    }
}

// MARK: - 상태바 아이콘 색 (안드로이드 `BrandStatusBar` · `StatusBarIcons`)

/// 분홍 머리 면 위에서는 **흰** 상태바 아이콘, 면이 지나가 흰 띠가 깔리면 **어두운** 아이콘.
///
/// SwiftUI 에는 화면마다 상태바 글자색을 정하는 API 가 없습니다(`preferredColorScheme` 은 창 전체의
/// 색 모드를 바꿔 시스템 색을 쓰는 곳까지 어두워집니다). 그래서 창의 맨 아래 컨트롤러가 이 값을
/// 따르게 하고(`StatusBarStyleCenter.install`), 화면은 나타난 동안만 요청을 올립니다 — 나중에 올린
/// 요청이 이깁니다. 머리 면이 사라지거나(밀어 넣은 화면·탭 전환) 흰 띠가 걷히면 요청도 내려갑니다.
@MainActor
final class StatusBarStyleCenter {
    static let shared = StatusBarStyleCenter()
    private var requests: [(id: UUID, style: UIStatusBarStyle)] = []
    private var installed: Set<ObjectIdentifier> = []

    var style: UIStatusBarStyle { requests.last?.style ?? .darkContent }

    func push(_ id: UUID, _ style: UIStatusBarStyle) {
        requests.removeAll { $0.id == id }
        requests.append((id, style))
        refresh()
    }
    func pop(_ id: UUID) {
        requests.removeAll { $0.id == id }
        refresh()
    }

    private func refresh() {
        for scene in UIApplication.shared.connectedScenes {
            guard let scene = scene as? UIWindowScene else { continue }
            for window in scene.windows {
                guard let root = window.rootViewController else { continue }
                install(on: root)
                root.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }

    /// SwiftUI 의 바탕 호스팅 컨트롤러(제네릭이라 하위 클래스를 만들 수 없음)의 실제 클래스에만
    /// `preferredStatusBarStyle` 을 갈아 끼웁니다. `childForStatusBarStyle` 을 비워야 안의
    /// 내비게이션 컨트롤러가 가져가지 않습니다.
    private func install(on root: UIViewController) {
        let cls: AnyClass = type(of: root)
        guard !installed.contains(ObjectIdentifier(cls)) else { return }
        installed.insert(ObjectIdentifier(cls))
        let style: @convention(block) (UIViewController) -> UIStatusBarStyle = { _ in
            MainActor.assumeIsolated { StatusBarStyleCenter.shared.style }
        }
        let child: @convention(block) (UIViewController) -> UIViewController? = { _ in nil }
        let styleSel = #selector(getter: UIViewController.preferredStatusBarStyle)
        let childSel = #selector(getter: UIViewController.childForStatusBarStyle)
        class_replaceMethod(cls, styleSel, imp_implementationWithBlock(style), "q@:")
        class_replaceMethod(cls, childSel, imp_implementationWithBlock(child), "@@:")
    }
}

/// 이 뷰가 화면에 있는 동안 상태바 아이콘 색을 요청합니다.
private struct StatusBarRequest: ViewModifier {
    let style: UIStatusBarStyle
    @State private var id = UUID()
    func body(content: Content) -> some View {
        content
            .onAppear { StatusBarStyleCenter.shared.push(id, style) }
            .onDisappear { StatusBarStyleCenter.shared.pop(id) }
    }
}

extension View {
    /// 분홍 면 위 — 흰 상태바 아이콘
    func wpLightStatusBar() -> some View { modifier(StatusBarRequest(style: .lightContent)) }
    /// 흰 바탕 위 — 어두운 상태바 아이콘
    func wpDarkStatusBar() -> some View { modifier(StatusBarRequest(style: .darkContent)) }
}

/// 안드로이드 `BrandStatusBar` — 머리 면이 지나간 뒤 상태바 뒤에 까는 흰 띠. 띠가 있는 동안 아이콘은 어둡게.
struct BrandStatusStrip: View {
    var body: some View {
        Color.white.frame(height: wpStatusBarHeight).frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .wpDarkStatusBar()
    }
}
