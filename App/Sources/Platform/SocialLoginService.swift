import AuthenticationServices
import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser
import WPModels
import WPNetworking

/// 로그인 두 갈래 — 카카오와 애플.
///
/// ## 왜 둘인가
///
/// **앱이 제3자 소셜 로그인만 제공하면 애플은 Sign in with Apple 을 함께 내라고
/// 요구한다**(심사 지침 4.8). 카카오 하나뿐이면 반려다.
///
/// ## 웹과 다른 점
///
/// 웹은 Next 서버 라우트를 거치는 OAuth 리다이렉트지만, 앱은 **SDK 가 토큰을 직접
/// 받아** 백엔드로 바꾼다. 그래서 `?kakao_login` 착지 구간이나 URL hash 처리가 없다.
@MainActor
final class SocialLoginService {

    /// 카카오 네이티브 앱 키. `Config/Local.xcconfig` → Info.plist 로 온다.
    ///
    /// **REST API 키·JS 키가 아니다.** 비어 있으면 SDK 를 켜지 않고 버튼 자리에
    /// 안내를 낸다 — 크래시가 아니라 설정 문제라고 말해 주는 편이 낫다.
    static var kakaoNativeAppKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
    }

    static var isKakaoConfigured: Bool { !kakaoNativeAppKey.isEmpty }

    /// 앱 시작 때 한 번. 키가 없으면 건너뛴다.
    static func initializeKakaoIfNeeded() {
        guard isKakaoConfigured else { return }
        KakaoSDK.initSDK(appKey: kakaoNativeAppKey)
    }

    /// 카카오톡/카카오계정에서 돌아오는 URL. `onOpenURL` 에서 넘긴다.
    static func handleKakaoOpenURL(_ url: URL) -> Bool {
        guard isKakaoConfigured, AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }

    // MARK: - 카카오

    /// 카카오 access_token 을 받아 백엔드의 앱 JWT 로 바꾼다.
    ///
    /// 본문 키는 **`kakaoToken`** 이다 — `accessToken` 으로 보내면 400 이다.
    func signInWithKakao(env: AppEnvironment) async throws {
        guard Self.isKakaoConfigured else {
            throw SocialLoginError.kakaoNotConfigured
        }

        let accessToken = try await kakaoAccessToken()
        let response = try await env.api.send(
            Endpoint.kakaoLogin(kakaoToken: accessToken),
            decoding: AuthToken.self
        )
        await env.tokenStore.save(response.token)
        await env.refreshAuthState()
    }

    /// 카카오톡이 깔려 있으면 앱으로, 아니면 카카오계정 웹으로.
    private func kakaoAccessToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let handler: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    continuation.resume(throwing: Self.mapKakao(error))
                } else if let accessToken = token?.accessToken {
                    continuation.resume(returning: accessToken)
                } else {
                    continuation.resume(throwing: SocialLoginError.failed)
                }
            }

            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: handler)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: handler)
            }
        }
    }

    /// 사용자가 스스로 취소한 것은 **오류로 알리지 않는다** — 누르다 만 것뿐이다.
    private static func mapKakao(_ error: Error) -> SocialLoginError {
        if let sdkError = error as? SdkError, sdkError.isClientFailed {
            switch sdkError.getClientError().reason {
            case .Cancelled: return .cancelled
            default: return .failed
            }
        }
        return .failed
    }

    // MARK: - 애플

    /// Sign in with Apple. `identityToken` 을 백엔드가 애플 공개키로 검증한다.
    ///
    /// **이름은 애플이 첫 로그인 때 한 번만 준다.** 그때 받은 것을 함께 보낸다 —
    /// 놓치면 영영 알 수 없다.
    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        env: AppEnvironment
    ) async throws {
        guard let data = credential.identityToken,
              let identityToken = String(data: data, encoding: .utf8)
        else {
            throw SocialLoginError.failed
        }

        let name = [credential.fullName?.familyName, credential.fullName?.givenName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined()

        let response = try await env.api.send(
            Endpoint.appleLogin(identityToken: identityToken, name: name.isEmpty ? nil : name),
            decoding: AuthToken.self
        )
        await env.tokenStore.save(response.token)
        await env.refreshAuthState()
    }
}

enum SocialLoginError: LocalizedError {
    case cancelled
    case kakaoNotConfigured
    case failed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .kakaoNotConfigured:
            return "카카오 앱 키가 설정되지 않았어요. 잠시 후 다시 시도해 주세요."
        case .failed:
            return "로그인하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    /// 사용자가 취소한 것은 화면에 띄우지 않는다.
    var isSilent: Bool { self == .cancelled }
}

/// `SocialLoginService` 를 뷰 생애주기에 매달기 위한 껍데기.
///
/// 서비스 자체는 상태가 없지만, `@StateObject` 로 들고 있어야 화면이 다시 그려질
/// 때마다 새로 만들어지지 않는다 — 로그인 콜백이 도중에 끊긴다.
@MainActor
final class LoginCoordinator: ObservableObject {
    let service = SocialLoginService()
}
