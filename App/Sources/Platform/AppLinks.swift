import Foundation
import UIKit

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

    /// 문의하기 메일.
    ///
    /// 제목은 웹 `SettingsPage.tsx`·안드로이드 `sendSupportMail` 과 **같은
    /// `[웨딩 플랜트] 문의`** 다. 받는 쪽에서 메일함 규칙으로 거르는 값이라
    /// 플랫폼마다 다르면 한쪽이 규칙에 안 걸린다.
    ///
    /// **본문에 버전·기기·iOS 버전을 미리 채운다.** 제보에서 가장 자주 빠지는
    /// 정보이고, 사용자에게 물으면 답이 오지 않는다. 사용자가 적을 자리는 맨
    /// 위에 비워 둔다 — 그래서 본문이 빈 줄 둘로 시작한다.
    ///
    /// 기기는 `UIDevice.model`("iPhone")이 아니라 **하드웨어 식별자**
    /// (`iPhone15,2`)를 쓴다. 어느 기종에서 난 문제인지가 답이어야 하는데
    /// 앞의 값은 전 기종이 똑같다.
    ///
    /// **옵셔널이다.** 메일 앱을 지운 기기에서는 이 주소를 열 수 없어
    /// `SupportLinks` 가 주소 복사로 떨어진다.
    static var support: URL? {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let system = UIDevice.current.systemVersion

        let body = """


---
앱 버전: \(version) (\(build))
기기: \(hardwareIdentifier)
iOS: \(system)
"""

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[웨딩 플랜트] 문의"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }

    /// `iPhone15,2` 같은 하드웨어 식별자. 시뮬레이터에서는 호스트 맥의 값이 온다.
    ///
    /// `machine` 은 고정 길이 C 배열이라 스위프트에서는 튜플로 온다. 바이트를
    /// 직접 읽어 첫 NUL 앞까지 자른다 — 뒤는 전부 0 패딩이라 그대로 문자열로
    /// 만들면 눈에 안 보이는 NUL 이 메일 본문에 따라 들어간다.
    ///
    /// **클로저 안에서 `info.machine` 을 다시 읽지 말 것.** `withUnsafePointer(to:)`
    /// 가 이미 배타적으로 잡고 있어서 크기를 구하려고 한 번 더 건드리면
    /// "overlapping accesses" 로 빌드가 깨진다(실제로 깨졌다). 버퍼가 자기 길이를
    /// 알고 있으므로 따로 셀 필요가 없다.
    private static var hardwareIdentifier: String {
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return machine.isEmpty ? "알 수 없음" : machine
    }
}
