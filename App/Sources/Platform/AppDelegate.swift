import OSLog
import UIKit

/// APNs 콜백을 받기 위한 델리게이트.
///
/// SwiftUI 만으로는 `didRegisterForRemoteNotificationsWithDeviceToken` 을 받을 방법이 없어서
/// `@UIApplicationDelegateAdaptor` 로 끼운다. 여기서 하는 일은 **토큰을 넘기는 것뿐**이고,
/// 나머지 판단은 ``PushService`` 가 한다.
final class AppDelegate: NSObject, UIApplicationDelegate {

    private static let log = Logger(
        subsystem: "app.weddingplant",
        category: "WPPush"
    )

    /// 앱 시작 시 ``WeddingPlantApp`` 이 꽂아 준다.
    @MainActor static weak var pushService: PushService?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 키보드를 편하게 내리는 앱 전체 규칙(바깥 탭 · 숫자 키패드 `완료`) — `KeyboardDismiss`
        MainActor.assumeIsolated { KeyboardDismiss.shared.start() }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            Self.pushService?.apply(apnsToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        // 유료 개발자 계정이 없으면 여기로 온다 — "no valid aps-environment entitlement".
        // 앱은 그대로 동작하고, 백그라운드 알림만 안 온다.
        Self.log.error("원격 알림 등록 실패: \(error.localizedDescription, privacy: .public)")
    }
}
