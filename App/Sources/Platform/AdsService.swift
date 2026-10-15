import GoogleMobileAds
import UserMessagingPlatform
import SwiftUI
import OSLog
import WPDomain

/// Consent and SDK startup happen only after the current user's plan is confirmed unpaid.
@MainActor final class AdsService: ObservableObject {
    static let shared = AdsService()
    private static let log = Logger(subsystem: "app.weddingplant", category: "Ads")
    @Published private(set) var ready = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var generation = 0
    private(set) var gate: AdGate = .unknown
    private var starting = false
    private var initialized = false
    private var consentChecked = false
    private var demo = false

    static var enabled: Bool {
        #if DEBUG
        return true
        #else
        return ["ADMOB_APP_ID", "ADMOB_NATIVE_AD_UNIT_ID", "ADMOB_BANNER_AD_UNIT_ID"].allSatisfy { !setting($0).isEmpty }
        #endif
    }
    static func setting(_ key: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains("$(") ? "" : value
    }
    static var nativeUnit: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/3986624511"
        #else
        return setting("ADMOB_NATIVE_AD_UNIT_ID")
        #endif
    }
    static var bannerUnit: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        return setting("ADMOB_BANNER_AD_UNIT_ID")
        #endif
    }
    static var presenter: UIViewController? {
        var view = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let next = view?.presentedViewController { view = next }
        return view
    }
    /// 판정이 바뀌면 받아 둔 광고를 버린다(Android `AdsSdk.release()`). 패스를 산 사람에게 남은 광고가 다시 그려지지 않게.
    private func bumpGeneration() {
        generation += 1
        NativeAdStore.shared.release()
    }
    func setGate(_ gate: AdGate, demo: Bool) {
        if self.gate != gate || self.demo != demo { bumpGeneration() }
        self.gate = gate; self.demo = demo
        guard gate == .show, Self.enabled else { ready = false; return }
        // UI fixture ads are explicit and never initialize an SDK or make an ad request.
        if demo && !ProcessInfo.processInfo.arguments.contains("-WPRealTestAds") { ready = false; return }
        Task { await startIfNeeded() }
    }
    private func startIfNeeded() async {
        guard !starting, gate == .show else { return }
        starting = true; defer { starting = false }
        if !consentChecked {
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
                guard gate == .show else { return }
                try await ConsentForm.loadAndPresentIfRequired(from: Self.presenter)
                consentChecked = true
            } catch { Self.log.notice("Consent update failed; cached SDK consent will be checked") }
        }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard gate == .show, ConsentInformation.shared.canRequestAds else { return }
        if !initialized {
            await withCheckedContinuation { continuation in
                MobileAds.shared.start { _ in continuation.resume() }
            }
            initialized = true
        }
        ready = gate == .show
        Self.log.notice("Ad SDK ready: \(self.ready)")
    }
    func presentPrivacyOptions() async {
        bumpGeneration(); ready = false
        do { try await ConsentForm.presentPrivacyOptionsForm(from: Self.presenter) }
        catch { Self.log.notice("Privacy options could not be presented") }
        await startIfNeeded()
    }
}

/// 견본 광고 — Android `PreviewAds`. SDK 를 부르지 않고 자리마다 지어낸 광고를 그린다.
///
/// 테스트 광고 단위도 NO_FILL 을 줄 때가 있어(Android 2026-10-11 에뮬레이터와 같은 일), 캡처로 **자리**를
/// 비교하려면 견본이 필요하다. 데모 모드에서만 켜진다 — 실제 백엔드로 도는 앱에는 절대 견본이 그려지지 않는다.
/// - UI 테스트·데모 실행: 실행 인자 `-WPAdPreview`
/// - 같은 프로세스에서 화면을 그리는 비교 테스트(`AllScreenComparisonTests`): `AdPreview.forced = true`
enum AdPreview {
    nonisolated(unsafe) static var forced = false
    static var requested: Bool { forced || ProcessInfo.processInfo.arguments.contains("-WPAdPreview") }
    static func active(isDemo: Bool) -> Bool { isDemo && requested }
}

struct AdPrivacyOptionsRow: View {
    @ObservedObject private var ads = AdsService.shared
    var body: some View {
        if ads.privacyOptionsRequired {
            Button("광고 개인정보 설정") { Task { await ads.presentPrivacyOptions() } }
                .font(WPFont.hak(14)).foregroundStyle(WPColor.fgMuted).padding(.vertical, 16)
        }
    }
}
