import SwiftUI
import WebKit

struct PassView: View {
    var roomId: Int?
    /// 청첩장 칸·플랜 추가에서 열었다 — 결제를 마쳐도 홈으로 가지 않는다(`PassPlansView.staysAfterPurchase`)
    var staysAfterPurchase = false
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var plans = false
    @State private var sample = false
    var body: some View {
        PassIntroCanvas(onAction: { action in
            switch action { case "close": dismiss(); case "plans": plans = true; case "sample": sample = true; default: break }
        }).ignoresSafeArea().background(Color(hex: 0x0B090F)).accessibilityIdentifier("pass.intro")
            .sheet(isPresented: $plans) { PassPlansView(roomId: roomId, staysAfterPurchase: staysAfterPurchase) }
            // 결제가 끝나면 소개도 닫는다(안드로이드 PassIntro) — 요금제 시트가 먼저 내려간 뒤에
            .onChange(of: env.passPurchase) { _, event in
                guard event != nil else { return }
                plans = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { dismiss() }
            }
            .fullScreenCover(isPresented: $sample) { InvitationPreviewView(content: InvitationStudioView.example) }
    }
}
extension PassView {
    /// 마무리 장면의 약속 칩에 「광고 없이」를 더한다 — 안드로이드 `PassIntro` 처럼 **광고가 있는 빌드에서만**
    /// (광고는 앱에만 있어 웹 `/pass` 원본 HTML 에는 이 칩이 없다).
    static let adsChipScript = "(function(){var p=document.querySelector('.pass-promise');if(p&&!p.querySelector('[data-ads]')){var s=document.createElement('span');s.setAttribute('data-ads','');s.textContent='광고 없이';p.appendChild(s);}})();"

    /// **그냥 스크롤되는 소개**(2026-10-16 사용자 "스크롤 이벤트 주니까 이상해").
    ///
    /// 웹 `/pass` 는 화면이 높으면 스크롤 거리로 장면을 넘기는 무대(sticky)가 되고, 높이 600 이하인 화면에서만 섹션이
    /// 아래로 이어지는 일반 문서(`flow`)가 된다. 앱에서는 **늘 그 일반 문서로** 보이게, 페이지가 높이 600 화면이라고
    /// 여기게 한다 — 스크립트의 `innerHeight` 와 CSS 의 높이 조건(`max-height` · `min-height`)을 600 기준으로 바꾼다.
    /// 원본 HTML(웹에서 복사해 온 파일)은 그대로 두어, 다시 복사해 와도 이 처리가 남는다.
    static let flowHeight = 600
    /// 문서 시작 — 페이지 스크립트가 읽기 전에 `innerHeight` 를 600 이하로.
    /// 열기 장면(`pass-opening.js`)은 카드를 **실제 화면** 가운데에 크게 두어야 해서 진짜 높이를 `wpViewportHeight()` 로
    /// 따로 연다 — 600 으로 계산하면 카드가 화면 위 30% 에 작게 섰다(2026-10-19 사용자 "가운데 크게 보였다가 줄어들어야").
    static let flowViewportScript = "(function(){var d=Object.getOwnPropertyDescriptor(window,'innerHeight');window.wpViewportHeight=function(){var h=document.documentElement?document.documentElement.clientHeight:0;return h||(d&&d.get?d.get.call(window):0)||\(flowHeight);};try{Object.defineProperty(window,'innerHeight',{configurable:true,get:function(){var h=document.documentElement?document.documentElement.clientHeight:0;return Math.min(\(flowHeight),h||\(flowHeight));}});}catch(e){}})();"
    /// 문서 끝 — CSS 의 높이 조건을 높이 600 화면 기준의 참·거짓으로 바꾸고 다시 재게 한다
    static let flowMediaScript = """
    (function(){var H=\(flowHeight);function fix(t){return t.replace(/\\(\\s*(max|min)-height\\s*:\\s*(\\d+)px\\s*\\)/g,function(_,k,n){n=+n;var ok=k==='max'?H<=n:H>=n;return ok?'(min-width: 0px)':'(max-width: 0px)';});}
    function walk(rules){for(var i=0;i<rules.length;i++){var r=rules[i];if(r.media){var t=r.media.mediaText,f=fix(t);if(f!==t)r.media.mediaText=f;}if(r.cssRules)walk(r.cssRules);}}
    for(var i=0;i<document.styleSheets.length;i++){try{walk(document.styleSheets[i].cssRules);}catch(e){}}
    var st=document.createElement('style');st.textContent='body::before{content:"";position:fixed;inset:0 0 auto;height:var(--safe-top,env(safe-area-inset-top));background:var(--night);z-index:19;pointer-events:none}.topbar{background:linear-gradient(var(--night) 0,var(--night) 70%,transparent)!important}';document.head.appendChild(st);
    window.dispatchEvent(new Event('resize'));})();
    """
}
/// Self-contained motion scene. Navigation and purchases stay in the app; it has no account/token access.
private struct PassIntroCanvas: UIViewRepresentable {
    let onAction: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onAction) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "pass")
        configuration.userContentController.addUserScript(WKUserScript(source: PassView.flowViewportScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController.addUserScript(WKUserScript(source: PassView.flowMediaScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
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

