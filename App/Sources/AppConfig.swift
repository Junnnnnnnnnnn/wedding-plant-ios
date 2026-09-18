import Foundation

/// 웹의 환경변수에 대응하는 앱 설정. 안드로이드 `core/AppConfig.kt` 와 같은 자리다.
///
/// | 웹 (.env)                | iOS (`Config/Local.xcconfig` → Info.plist) |
/// | ------------------------ | ------------------------------------------ |
/// | NEXT_PUBLIC_API_BASE_URL | `API_BASE_URL`                             |
/// | NEXT_PUBLIC_SITE_URL     | `WEB_BASE_URL`                             |
///
/// - Note: xcconfig 에서 `//` 는 주석이라 주소를 `https:/$()/…` 로 적어야 한다.
enum AppConfig {

    /// 웹 사이트 주소. **공유 링크를 만들 때 쓴다.**
    ///
    /// 웹은 `window.location.origin` 을 쓰지만 앱에는 origin 이 없어 설정으로 받는다.
    /// 값이 없으면 운영 주소로 떨어진다 — 초대 링크가 빈 문자열이 되면 그 자리에서
    /// 초대가 끊기고, 사용자는 왜 안 되는지 알 방법이 없다.
    static let webBaseURL: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "WEB_BASE_URL") as? String ?? "")
            .trimmingCharacters(in: .whitespaces)
        let trimmed = raw.hasSuffix("/") ? String(raw.dropLast()) : raw
        return trimmed.isEmpty ? "https://weddingplant.app" : trimmed
    }()

    /// 개인정보처리방침. 웹의 공개 페이지를 그대로 쓴다.
    ///
    /// **스토어 심사에 필요하다** — 앱이 개인정보를 수집하면 접근 가능한 URL 을
    /// 요구하고, 앱 안에서도 찾을 수 있어야 한다.
    static var privacyURL: String { webBaseURL + "/privacy" }
}
