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
/// Self-contained motion scene. Navigation and purchases stay in the app; it has no account/token access.
private struct PassIntroCanvas: UIViewRepresentable {
    let onAction: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onAction) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "pass")
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
