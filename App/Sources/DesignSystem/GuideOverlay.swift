import SwiftUI

/// 웹 `app/components/GuideOverlay.tsx` 이식.
///
/// - 대상 영역만 뚫린 검은 스크림
/// - **아무 데나 누르면 다음 단계.** 오버레이에 "다음" 버튼은 없다.
/// - 우상단 X 로 즉시 닫힘
///
/// **앵커를 지우거나 이름을 바꾸지 말 것.** 대상을 못 찾으면 스팟라이트가 0×0 으로
/// 붕괴해 화면만 까맣게 덮인다(웹에서 실제로 그랬다). 그래서 여기서는 앵커가
/// 없으면 말풍선을 **화면 가운데**에 띄운다.
struct GuideStep: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var description: String
    /// 말풍선을 스팟라이트 **위**에 붙인다(웹 `tooltipPosition: "above"`).
    var tooltipAbove: Bool = false
    /// 말풍선을 화면 가운데로 정렬한다(웹 `tooltipAlign: "center"`).
    var tooltipCenter: Bool = false
}

/// 가이드 대상의 좌표를 모으는 저장소.
///
/// 웹은 `document.getElementById(step.id)` 로 DOM 을 찾지만 SwiftUI 에는 그런 전역
/// 조회가 없다. 대신 각 요소가 ``SwiftUI/View/guideAnchor(_:)`` 로 자기 좌표를
/// 여기에 등록한다.
@MainActor
final class GuideAnchors: ObservableObject {
    @Published private(set) var bounds: [String: CGRect] = [:]

    func put(_ id: String, _ rect: CGRect) {
        // 같은 값이면 다시 그리지 않는다 — 스크롤 중에 매 프레임 갱신되면
        // 오버레이가 떨린다.
        if let old = bounds[id], old.equalTo(rect) { return }
        bounds[id] = rect
    }

    func rect(_ id: String) -> CGRect? { bounds[id] }
}

/// 가이드를 띄우라는 신호.
///
/// 오버레이는 **하단 탭바까지 덮어야** 하는데 탭바는 화면 바깥(셸)에 있다.
/// 그래서 오버레이는 셸에서 그리고, 띄우라는 신호만 여기로 올려보낸다.
@MainActor
final class GuideController: ObservableObject {
    @Published private(set) var steps: [GuideStep] = []
    @Published private(set) var visible = false

    private var onClosed: (() -> Void)?

    func show(_ steps: [GuideStep], onClosed: @escaping () -> Void = {}) {
        guard !steps.isEmpty else { return }
        self.steps = steps
        self.onClosed = onClosed
        visible = true
    }

    func close() {
        guard visible else { return }
        visible = false
        onClosed?()
        onClosed = nil
    }
}

private struct GuideAnchorsKey: EnvironmentKey {
    @MainActor static let defaultValue = GuideAnchors()
}

extension EnvironmentValues {
    var guideAnchors: GuideAnchors {
        get { self[GuideAnchorsKey.self] }
        set { self[GuideAnchorsKey.self] = newValue }
    }
}

extension View {
    /// 이 요소를 가이드 스팟라이트 대상으로 등록한다.
    /// 웹의 `id="main-budget-card"` 에 대응한다.
    func guideAnchor(_ id: String) -> some View {
        modifier(GuideAnchorModifier(id: id))
    }
}

private struct GuideAnchorModifier: ViewModifier {
    var id: String
    @Environment(\.guideAnchors) private var anchors

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    anchors.put(id, geo.frame(in: .global))
                }
                .onChange(of: geo.frame(in: .global)) { _, rect in
                    anchors.put(id, rect)
                }
            }
        )
    }
}

/// 검은 스크림 + 대상만 뚫린 구멍 + 말풍선.
struct GuideOverlay: View {
    var steps: [GuideStep]
    @ObservedObject var anchors: GuideAnchors
    var onClose: () -> Void

    @State private var index = 0

    private var step: GuideStep? {
        steps.indices.contains(index) ? steps[index] : nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                scrim
                if let step {
                    if let rect = anchors.rect(step.id), rect.width > 0, rect.height > 0 {
                        spotlight(rect)
                        bubble(step, near: rect, in: geo.size)
                    } else {
                        // **앵커를 못 찾아도 글은 보여야 한다.** 예전에는 까만
                        // 배경만 깔려 아무것도 안 보였다.
                        bubbleCard(step)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                closeButton
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: advance)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("guide.overlay")
    }

    /// 대상만 뚫린 스크림. `blendMode(.destinationOut)` 으로 구멍을 낸다.
    private var scrim: some View {
        ZStack {
            Color.black.opacity(0.6)
            if let step, let rect = anchors.rect(step.id), rect.width > 0, rect.height > 0 {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .frame(width: rect.width + 12, height: rect.height + 12)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    private func spotlight(_ rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
            .frame(width: rect.width + 12, height: rect.height + 12)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    private func bubble(_ step: GuideStep, near rect: CGRect, in size: CGSize) -> some View {
        // 말풍선이 화면 밖으로 나가지 않게 위아래를 자동으로 고른다.
        let above = step.tooltipAbove || rect.maxY + 160 > size.height
        let y = above ? max(90, rect.minY - 24) : min(size.height - 40, rect.maxY + 24)

        return bubbleCard(step)
            .frame(maxWidth: min(320, size.width - 40))
            .position(
                x: step.tooltipCenter ? size.width / 2 : min(max(rect.midX, 180), size.width - 180),
                y: above ? y - 60 : y + 60
            )
    }

    private func bubbleCard(_ step: GuideStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(WPFont.hak(16, .bold))
                .foregroundStyle(WPColor.textPrimary)
            Text(step.description)
                .font(WPFont.hak(13.5))
                .lineSpacing(6)
                .foregroundStyle(WPColor.fgMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text("\(index + 1) / \(steps.count)")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.fgSubtle)
                Spacer(minLength: 0)
                // 오버레이에 "다음" 버튼은 없다 — **아무 데나 누르면 넘어간다.**
                Text(index == steps.count - 1 ? "눌러서 닫기" : "눌러서 다음")
                    .font(WPFont.hak(12, .bold))
                    .foregroundStyle(WPColor.primary)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: 320, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 6)
        .padding(.horizontal, 20)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 56)
        .padding(.trailing, 16)
        .accessibilityLabel("가이드 닫기")
    }

    private func advance() {
        if index < steps.count - 1 {
            index += 1
        } else {
            onClose()
        }
    }
}
