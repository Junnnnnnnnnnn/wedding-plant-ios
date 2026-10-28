import Foundation

/// 새 버전 알림 — Android `domain/UpdateRules.kt`(373ec6f, 2026-10-28).
///
/// 스토어에 지금보다 **새 버전이 있으면 늘 `업데이트 / 나중에`** 를 낸다. `나중에` 는 이번 안내만 닫고 다음 진입에 다시 묻는다.
/// 예전 Android 의 24시간 숨김 · 30분 간격 · 꼭 해야 하는 업데이트(나중에 없음)는 쓰지 않는다(2026-10-28 사용자).
///
/// Android 는 Play In-App Updates 가 판정하고 버전 **코드**(정수)를 비교한다. iOS 는 App Store 조회(`itunes.apple.com/lookup`)의
/// 버전 **문자열**(CFBundleShortVersionString)을 비교한다 — 같은 1.0.1 안의 TestFlight 빌드 번호는 스토어에 없으니 볼 수 없다.
public enum UpdateRules {
    public struct Offer: Equatable, Sendable {
        public let version: String
        /// App Store 의 이 앱 페이지(`trackViewUrl`)
        public let storeURL: URL
        public init(version: String, storeURL: URL) { self.version = version; self.storeURL = storeURL }
    }

    /// `1.0.10` > `1.0.9`, `1.1` == `1.1.0` — 점으로 나눈 숫자를 차례로 비교한다. 숫자가 아닌 꼬리(`1.2b`)는 앞의 숫자만 본다.
    public static func isNewer(_ store: String, than installed: String) -> Bool {
        let a = parts(store), b = parts(installed)
        guard !a.isEmpty, !b.isEmpty else { return false }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0, y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// 스토어가 준 값으로 안내할지. 이 기기의 iOS 가 그 버전의 최소 버전보다 낮으면 받을 수 없으니 묻지 않는다
    /// (Play 가 받을 수 있는 업데이트만 알려 주는 것과 같게).
    public static func decide(storeVersion: String?, storeURL: URL?, minimumOS: String?, installedVersion: String, osVersion: String) -> Offer? {
        guard let storeVersion, let storeURL, isNewer(storeVersion, than: installedVersion) else { return nil }
        if let minimumOS, isNewer(minimumOS, than: osVersion) { return nil }
        return Offer(version: storeVersion, storeURL: storeURL)
    }

    private static func parts(_ version: String) -> [Int] {
        version.trimmingCharacters(in: .whitespaces).split(separator: ".").map { piece in
            Int(piece.prefix { $0.isNumber }) ?? 0
        }
    }

    public static let title = "새 버전이 나왔어요"
    public static let body = "고친 점과 새 기능이 담긴 버전이에요. 지금 업데이트할까요?"
    public static let update = "업데이트"
    public static let later = "나중에"
}
