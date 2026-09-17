import Foundation

/// 앱에서 여는 웹 주소.
///
/// 웹 주소는 `Config/Base.xcconfig` 의 `WEB_BASE_URL` → Info.plist 로 들어온다
/// (안드로이드의 `WEB_BASE_URL`, 웹의 `NEXT_PUBLIC_SITE_URL` 과 같은 값이어야 한다).
enum AppLinks {
    /// 웹 사이트 주소. 설정이 없거나 깨졌으면 운영 주소를 쓴다 —
    /// 개인정보처리방침 링크가 없는 화면은 심사에서 반려된다.
    static let webBase: URL = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "WEB_BASE_URL") as? String,
           let url = URL(string: raw.trimmingCharacters(in: .whitespaces)),
           url.scheme != nil {
            return url
        }
        return URL(string: "https://weddingplant.app")!
    }()

    /// 개인정보처리방침. 웹의 `/privacy` 는 로그인 없이 열리는 공개 문서다.
    static var privacyPolicy: URL { webBase.appendingPathComponent("privacy") }
}
