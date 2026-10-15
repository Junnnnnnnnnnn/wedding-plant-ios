import SwiftUI
import WebKit

struct PassView: View {
    var roomId: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var plans = false
    @State private var sample = false
    var body: some View {
        PassIntroCanvas(onAction: { action in
            switch action { case "close": dismiss(); case "plans": plans = true; case "sample": sample = true; default: break }
        }).ignoresSafeArea().background(Color(hex: 0x0B090F)).accessibilityIdentifier("pass.intro")
            .sheet(isPresented: $plans) { PassPlansView(roomId: roomId) }
            .fullScreenCover(isPresented: $sample) { InvitationPreviewView(content: InvitationStudioView.example) }
    }
}
extension PassView {
    /// 마무리 장면의 약속 칩에 「광고 없이」를 더한다 — 안드로이드 `PassIntro` 처럼 **광고가 있는 빌드에서만**
    /// (광고는 앱에만 있어 웹 `/pass` 원본 HTML 에는 이 칩이 없다).
    static let adsChipScript = "(function(){var p=document.querySelector('.pass-promise');if(p&&!p.querySelector('[data-ads]')){var s=document.createElement('span');s.setAttribute('data-ads','');s.textContent='광고 없이';p.appendChild(s);}})();"
}
/// Self-contained motion scene. Navigation and purchases stay in the app; it has no account/token access.
private struct PassIntroCanvas: UIViewRepresentable {
    let onAction: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onAction) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "pass")
        if AdsService.enabled {
            configuration.userContentController.addUserScript(WKUserScript(source: PassView.adsChipScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false; view.backgroundColor = .clear
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.showsVerticalScrollIndicator = false
        if let url = Bundle.main.url(forResource: "pass-intro", withExtension: "html") {
            view.loadFileURL(url, allowingReadAccessTo: Bundle.main.bundleURL)
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading(); view.configuration.userContentController.removeScriptMessageHandler(forName: "pass")
    }
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let action: (String) -> Void
        init(_ action: @escaping (String) -> Void) { self.action = action }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let value = message.body as? String, ["close","plans","sample"].contains(value) else { return }; action(value)
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.scheme == "weddingplant-pass", url.host == "plans" {
                action("plans"); decisionHandler(.cancel); return
            }
            // Only bundled resources and local fragment links are part of this scene.
            decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
        }
    }
}

// MARK: - 새 버전 알림 (안드로이드 `ui/components/UpdateDialog.kt`)

/// 새 버전 알림 카드 — 안드로이드와 같은 흰 카드 + 알약 버튼, 맨 위 로고(하트 새싹).
///
/// **모양만 옮겼다.** 안드로이드는 Play In-App Updates 가 스토어 버전을 알려 주지만 iOS 에는 그에 해당하는
/// 판정이 아직 없다(App Store 버전 조회·강제 기준을 정하지 않음). 띄우는 쪽이 생기면 `force` 로 `나중에` 를
/// 빼고, `onUpdate` 는 App Store 페이지를 연다. 공용 컴포넌트 파일이 여러 화면 작업과 겹쳐 우선 여기에 둔다.
struct UpdateDialog: View {
    var force: Bool
    var onUpdate: () -> Void
    var onLater: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if !force { onLater() } }
            UpdateCard(force: force, onUpdate: onUpdate, onLater: onLater).padding(16)
        }
    }
}

struct UpdateCard: View {
    var force: Bool
    var onUpdate: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WPColor.brand100)
                if let logo = UIImage(named: "app_logo") {
                    Image(uiImage: logo).resizable().scaledToFit().frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }.frame(width: 64, height: 64)
            Text("새 버전이 나왔어요").tracking(-0.38).foregroundColor(WPColor.textPrimary)
                .wpTypography(19, .bold).multilineTextAlignment(.center).padding(.top, 16)
            PassParagraph(text: force ? "꼭 필요한 업데이트예요. 업데이트한 뒤 이어서 써 주세요." : "고친 점과 새 기능이 담긴 버전이에요. 지금 업데이트할까요?",
                          size: 14.5, lineHeight: 22, color: WPColor.stone600, alignment: .center).padding(.top, 8)
            VStack(spacing: 10) {
                pill("업데이트", background: WPColor.primary, content: .white, border: nil, action: onUpdate).accessibilityIdentifier("update.confirm")
                if !force {
                    pill("나중에", background: .white, content: WPColor.stone600, border: WPColor.stone300, action: onLater).accessibilityIdentifier("update.later")
                }
            }.padding(.top, 24)
        }
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 24)
        .frame(maxWidth: 384)
        // 그림자는 카드 면에만 — 안의 버튼·로고에 번지지 않게
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white).shadow(color: .black.opacity(0.18), radius: 20, y: 8))
    }

    private func pill(_ label: String, background: Color, content: Color, border: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).wpTypography(15, .bold).foregroundStyle(content).lineLimit(1).padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(background, in: Capsule())
                .overlay { if let border { Capsule().strokeBorder(border, lineWidth: 1.5) } }
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }
}
