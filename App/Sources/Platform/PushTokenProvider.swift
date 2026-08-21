import Foundation
import OSLog
import WPDomain

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// 백엔드에 등록할 기기 토큰을 만들어 주는 쪽.
///
/// 백엔드는 안드로이드와 같은 **FCM** 으로 보낸다. 그래서 iOS 도 FCM 등록 토큰을 보내야 한다.
/// 다만 `GoogleService-Info.plist` 가 없으면(공개 저장소·CI) Firebase 를 켤 수 없으므로,
/// 그 경우 **APNs 원시 토큰**으로 물러난다 — 백엔드가 APNs 로 직접 쏘는 구성이면 그대로 동작한다.
@MainActor
protocol PushTokenProviding: AnyObject {
    /// 토큰이 생기거나 갱신될 때마다 불린다.
    var onToken: ((String) -> Void)? { get set }

    /// 앱 시작 시 한 번. Firebase 가 있으면 켠다.
    func start()

    /// APNs 가 준 기기 토큰을 넘긴다. FCM 은 이걸 받아야 등록 토큰을 만든다.
    func apply(apnsToken: Data)

    /// 지금 가진 토큰. 없으면 nil.
    func currentToken() async -> String?
}

/// Firebase 가 링크돼 있고 설정 파일이 있으면 FCM 토큰을, 아니면 APNs 토큰을 준다.
@MainActor
final class PushTokenProvider: NSObject, PushTokenProviding {

    private static let log = Logger(
        subsystem: "com.zipshowkorea.weddingplant",
        category: "WPPush"
    )

    var onToken: ((String) -> Void)?

    /// APNs 가 준 원시 토큰(16진). Firebase 가 없을 때 이걸 그대로 보낸다.
    private var apnsHexToken: String?

    /// Firebase 를 실제로 켰는지. 설정 파일이 없으면 false.
    private(set) var usesFirebase = false

    func start() {
        #if canImport(FirebaseCore)
        // `GoogleService-Info.plist` 가 없는데 configure() 를 부르면 앱이 죽는다.
        // 공개 저장소라 이 파일은 커밋하지 않으므로 CI·시뮬레이터에서는 항상 없다.
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
        else {
            Self.log.notice("GoogleService-Info.plist 가 없어 FCM 없이 동작합니다 (APNs 토큰 사용)")
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        usesFirebase = true
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        Self.log.notice("FCM 활성화")
        #else
        Self.log.notice("Firebase 미링크 — APNs 토큰을 그대로 등록합니다")
        #endif
    }

    func apply(apnsToken: Data) {
        let hex = PushRouting.hexToken(apnsToken)
        apnsHexToken = hex
        Self.log.debug("APNs 토큰 수신 (\(hex.count, privacy: .public)자)")

        #if canImport(FirebaseMessaging)
        if usesFirebase {
            // FCM 은 APNs 토큰을 받아야 등록 토큰을 발급한다.
            Messaging.messaging().apnsToken = apnsToken
            return
        }
        #endif
        onToken?(hex)
    }

    func currentToken() async -> String? {
        #if canImport(FirebaseMessaging)
        if usesFirebase {
            return try? await Messaging.messaging().token()
        }
        #endif
        return apnsHexToken
    }
}

#if canImport(FirebaseMessaging)
extension PushTokenProvider: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
        guard let token, !token.isEmpty else { return }
        Task { @MainActor in
            Self.log.debug("FCM 등록 토큰 갱신")
            onToken?(token)
        }
    }
}
#endif
