import SwiftUI
import UIKit

/// Android `Toast.makeText` 대응 — 화면 아래에 잠깐 뜨는 한 줄 알림.
///
/// 화면이 닫히는 순간에도 남아야 하는 말(저장 뒤 서류를 못 올림 등)이 있어 화면 상태가 아니라 앱에 둡니다.
/// 그리는 곳은 `RootView` 한 곳입니다.
@MainActor
final class AppToast: ObservableObject {
    static let shared = AppToast()
    @Published private(set) var message: String?
    private var hideTask: Task<Void, Never>?

    /// 맨 위 창 — 전체 화면 창(완료 카드 · 패스 소개)이 떠 있어도 그 위에 보인다(Android 토스트는 앱 화면 위의 시스템 창).
    /// 누름은 받지 않고 그 아래로 지나간다.
    private var window: UIWindow?

    /// Android `LENGTH_SHORT`(2초) · `LENGTH_LONG`(3.5초)
    func show(_ text: String, long: Bool = false) {
        installWindow()
        message = text
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(long ? 3.5 : 2))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}

private extension AppToast {
    func installWindow() {
        if window?.windowScene != nil { return }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        else { return }
        let host = UIHostingController(rootView: AppToastHost())
        host.view.backgroundColor = .clear
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = host
        window.isUserInteractionEnabled = false
        window.isHidden = false
        self.window = window
    }
}

/// 아래 가운데의 어두운 알약(Android 기본 토스트 자리)
struct AppToastHost: View {
    @ObservedObject var toast = AppToast.shared

    var body: some View {
        VStack {
            Spacer()
            if let message = toast.message {
                Text(message)
                    .wpTypography(14)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Color(hex: 0x333333).opacity(0.94), in: Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 96)
                    .transition(.opacity)
                    .accessibilityIdentifier("app.toast")
            }
        }
        .animation(.easeOut(duration: 0.2), value: toast.message)
        .allowsHitTesting(false)
    }
}
