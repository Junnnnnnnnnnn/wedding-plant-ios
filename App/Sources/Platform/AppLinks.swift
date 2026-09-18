import Foundation

/// 앱에서 여는 웹 주소.
///
/// 웹 주소는 `Config/Base.xcconfig` 의 `WEB_BASE_URL` → Info.plist 로 들어온다
/// (안드로이드의 `WEB_BASE_URL`, 웹의 `NEXT_PUBLIC_SITE_URL` 과 같은 값이어야 한다).
enum AppLinks {
    /// 웹 사이트 주소. **정답은 `AppConfig.webBaseURL` 한 곳**이다 —
    /// 예전에는 여기와 `AppConfig` 가 같은 일을 따로 해서, 한쪽만 고치면
    /// 초대 링크와 방침 링크가 다른 주소를 가리킬 수 있었다.
    static var webBase: URL {
        URL(string: AppConfig.webBaseURL) ?? URL(string: "https://weddingplant.app")!
    }

    /// 개인정보처리방침. 웹의 `/privacy` 는 로그인 없이 열리는 공개 문서다.
    ///
    /// **앱 안에 접근 경로가 있는지를 심사에서 본다.**
    static var privacyPolicy: URL { webBase.appendingPathComponent("privacy") }

    /// 문의하기.
    ///
    /// 애플이 **필수로 요구하는 것은 App Store Connect 의 지원 URL**(지침 1.5)이고
    /// 앱 안의 문의 버튼 자체가 지침 항목은 아니다. 다만 계정이 있는 앱은 심사자가
    /// 지원 경로를 확인하는 경우가 있고, 무엇보다 **사용자가 막혔을 때 나갈 길**이
    /// 생긴다.
    ///
    /// 제목·본문에 앱 버전을 미리 채운다 — 문의가 오면 어느 빌드인지부터 묻지
    /// 않아도 된다.
    static var support: URL {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let system = "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        let subject = "웨딩플랜트 문의"
        let body = "\n\n———\n앱 \(version) (\(build))\n\(system)"

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url ?? URL(string: "mailto:\(AppConfig.supportEmail)")!
    }
}
