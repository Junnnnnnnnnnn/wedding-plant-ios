import Combine
import Foundation
import OSLog
import UIKit
import UserNotifications
import WPDomain
import WPModels
import WPNetworking

/// 백그라운드 알림(APNs, FCM 경유).
///
/// 앱이 켜져 있는 동안의 알림은 소켓·SSE 가 맡는다. 여기는 **앱이 꺼져 있거나 백그라운드일 때**를 담당한다.
///
/// - Important: 실제로 배달되려면 **Apple Developer Program(유료)** 이 필요하다.
///   무료 Apple ID 로는 Push Notifications capability 자체가 서명되지 않는다.
///   그래서 `aps-environment` 엔타이틀먼트는 `WP_ENTITLEMENTS` 로 켜고 끄게 해 두었다
///   (`Config/Local.xcconfig`). 켜지 않아도 앱은 그대로 빌드·실행된다.
@MainActor
final class PushService: NSObject, ObservableObject {

    private static let log = Logger(
        subsystem: "com.zipshowkorea.weddingplant",
        category: "WPPush"
    )

    /// 인앱 토스트로 보여줄 문구. 앱이 켜져 있을 때만 채워진다.
    @Published var toast: String?

    /// 알림을 눌러서 들어갈 채팅방.
    @Published var pendingChatRoomId: Int?

    /// 지금 열려 있는 채팅방. 이 방의 알림은 배너도 토스트도 띄우지 않는다.
    var currentChatRoomId: Int?

    private let tokenProvider: any PushTokenProviding
    private weak var env: AppEnvironment?

    /// 마지막으로 백엔드에 등록한 토큰. 로그아웃 때 해제에 쓴다.
    private var registeredToken: String?

    init(tokenProvider: any PushTokenProviding = PushTokenProvider()) {
        self.tokenProvider = tokenProvider
        super.init()
    }

    // MARK: - 시작

    func start(env: AppEnvironment) {
        self.env = env
        UNUserNotificationCenter.current().delegate = self

        tokenProvider.onToken = { [weak self] token in
            Task { await self?.register(token: token) }
        }
        tokenProvider.start()
    }

    /// 알림 권한을 요청하고, 허용되면 APNs 에 등록한다.
    ///
    /// 첫 화면에서 바로 묻지 않는다 — 로그인 직후에 부르는 것이 거절률이 낮다.
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound]))
                ?? false
            Self.log.notice("알림 권한: \(granted ? "허용" : "거부", privacy: .public)")
            guard granted else { return }
        case .denied:
            // 사용자가 껐다. 설정에서 켜야 하므로 여기서 할 일은 없다.
            return
        default:
            break
        }

        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - 토큰 등록 · 해제

    func apply(apnsToken: Data) {
        tokenProvider.apply(apnsToken: apnsToken)
    }

    /// 로그인 직후에도 한 번 부른다.
    ///
    /// - Important: **설치 후 첫 로그인에는 토큰 갱신 콜백이 오지 않는다.**
    ///   갱신 때만 등록하면 새로 깐 기기에 알림이 영영 안 온다.
    func registerCurrentToken() async {
        guard let token = await tokenProvider.currentToken() else { return }
        await register(token: token)
    }

    private func register(token: String) async {
        guard let env else { return }
        let loggedIn = await env.tokenStore.currentToken()?.isEmpty == false
        guard loggedIn else {
            // 로그인 전에는 등록해도 백엔드가 누구의 기기인지 알 수 없다.
            registeredToken = token
            return
        }

        do {
            try await env.api.sendIgnoringData(Endpoint.registerDeviceToken(token))
            registeredToken = token
            Self.log.notice("기기 토큰 등록 완료")
        } catch {
            Self.log.error("기기 토큰 등록 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 로그아웃 시 해제.
    ///
    /// - Important: **JWT 를 지우기 전에** 불러야 한다. `DELETE /plan/user/device-token` 은
    ///   `Authorization` 이 필요하다. 해제하지 않으면 로그아웃해도 그 기기로 알림이 계속 가고,
    ///   기기를 넘기거나 공용 기기를 쓰면 남의 채팅 내용이 그대로 뜬다.
    func unregisterBeforeSignOut(env: AppEnvironment) async {
        guard let token = registeredToken ?? (await tokenProvider.currentToken()) else { return }
        do {
            try await env.api.sendIgnoringData(Endpoint.unregisterDeviceToken(token))
            Self.log.notice("기기 토큰 해제 완료")
        } catch {
            // 실패해도 로그아웃은 계속 진행한다. 여기서 막으면 로그아웃 자체가 안 된다.
            Self.log.error("기기 토큰 해제 실패: \(error.localizedDescription, privacy: .public)")
        }
        registeredToken = nil
    }
}

// MARK: - 알림 표시 · 탭

extension PushService: UNUserNotificationCenterDelegate {

    /// 앱이 켜져 있을 때 알림이 도착했다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        return await MainActor.run {
            let payload = PushPayload(userInfo: userInfo)
            switch PushRouting.display(
                for: payload,
                appActive: true,
                currentChatRoomId: currentChatRoomId
            ) {
            case .suppress:
                // 지금 보고 있는 대화다. 소켓으로 이미 화면에 떴다.
                return []
            case .inAppOnly:
                toast = PushRouting.toastText(for: payload)
                return []
            case .system:
                return [.banner, .sound]
            }
        }
    }

    /// 알림을 눌렀다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            let payload = PushPayload(userInfo: userInfo)
            if case let .chatRoom(id) = PushRouting.destination(for: payload) {
                pendingChatRoomId = id
            }
        }
    }
}
