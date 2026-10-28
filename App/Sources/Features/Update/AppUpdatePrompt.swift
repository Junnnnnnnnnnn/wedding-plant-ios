import AudioToolbox
import SwiftUI
import UIKit
import WPDomain

/// 새 버전 알림 — Android `core/update/AppUpdateChecker` · `AppNavHost.AppUpdatePrompt`(373ec6f, 2026-10-28).
///
/// - **앱을 켜거나 백그라운드에서 다시 들어올 때마다** App Store 에 한 번 묻는다. 제어 센터 · 권한 창으로 잠깐 `inactive`
///   가 된 것은 재진입이 아니다(Android `ON_PAUSE` 를 세지 않는 것과 같음).
/// - 새 버전이면 늘 `업데이트 / 나중에`. `나중에` 는 이번 안내만 닫고 다음 진입에 다시 묻는다.
/// - 조회는 10초 안에 끝나지 않으면 버린다. **실패를 "최신" 으로 적지 않는다** — 떠 있던 안내를 지우지도 않는다.
///   백그라운드로 가면 조회를 취소하고, 조회 중에 사람이 안내에서 고르면 늦게 온 답으로 다시 띄우지 않는다.
/// - Android 는 Play 가 아는 버전 코드를 보지만 iOS 는 공개 조회 API(`itunes.apple.com/lookup`)의 버전 문자열을 본다.
///   아직 스토어에 없는 앱(심사 중)이면 결과가 0 개라 아무것도 띄우지 않는다.
/// - 안내는 **자기 창**(경고 창 높이)에 띄운다 — 시트 · 전체 화면 편집기 위에서도 보이게(Android 대화상자는 창이 따로다).
@MainActor
final class AppUpdatePrompt {
    static let shared = AppUpdatePrompt()

    private(set) var pending: UpdateRules.Offer? { didSet { render() } }
    private var check: Task<Void, Never>?
    private var decisions = 0
    private var window: UIWindow?

    /// 앱에 들어왔다(켬 · 백그라운드에서 돌아옴)
    func enter() {
        check?.cancel()
        let decisionAtStart = decisions
        check = Task { [weak self] in
            let result = await Self.lookup()
            guard let self, !Task.isCancelled, self.decisions == decisionAtStart else { return }
            // nil = 묻지 못함 → 떠 있던 것을 그대로 둔다. `.some(nil)` = 새 버전 없음
            if let result { self.pending = result }
        }
    }

    /// 백그라운드로 갔다 — 조회를 취소한다(다음 진입에서 다시)
    func leave() {
        decisions += 1
        check?.cancel()
        check = nil
    }

    func later() {
        decisions += 1
        pending = nil
    }

    func update() {
        guard let url = pending?.storeURL else { return }
        decisions += 1
        pending = nil
        UIApplication.shared.open(url)
    }

    // MARK: - App Store 조회

    private struct Lookup: Decodable {
        struct Item: Decodable { let version: String?; let trackViewUrl: String?; let minimumOsVersion: String? }
        let results: [Item]
    }

    /// nil 이면 묻지 못했다(네트워크 · 시간 초과 · 이상한 답). `.some(nil)` 이면 새 버전이 없다.
    nonisolated private static func lookup() async -> UpdateRules.Offer?? {
        let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let os = await MainActor.run { UIDevice.current.systemVersion }
        let arguments = ProcessInfo.processInfo.arguments
        // `-WPStoreVersion 9.9.9` — UI 테스트 · 화면 확인용 가짜 스토어(네트워크 없음)
        if let index = arguments.firstIndex(of: "-WPStoreVersion"), index + 1 < arguments.count {
            return .some(UpdateRules.decide(storeVersion: arguments[index + 1], storeURL: URL(string: "https://apps.apple.com/kr/app/id0"),
                                            minimumOS: nil, installedVersion: installed, osVersion: os))
        }
        // 데모 모드는 운영 스토어에 묻지 않는다
        if arguments.contains("-WPDemoMode") { return nil }
        guard let bundleId = Bundle.main.bundleIdentifier,
              var components = URLComponents(string: "https://itunes.apple.com/lookup") else { return nil }
        // 조회 API 는 CDN 에 오래 남아 새 버전을 늦게 안다 — 매번 다른 주소로 캐시를 비켜 간다
        components.queryItems = [.init(name: "bundleId", value: bundleId), .init(name: "country", value: "kr"),
                                 .init(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let body = try? JSONDecoder().decode(Lookup.self, from: data) else { return nil }
        guard let item = body.results.first else { return .some(nil) }
        return .some(UpdateRules.decide(storeVersion: item.version, storeURL: item.trackViewUrl.flatMap(URL.init(string:)),
                                        minimumOS: item.minimumOsVersion, installedVersion: installed, osVersion: os))
    }

    // MARK: - 창

    private func render() {
        guard pending != nil else {
            window?.isHidden = true
            window = nil
            return
        }
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let host = UIHostingController(rootView: UpdateDialog(onUpdate: { [weak self] in self?.update() },
                                                              onLater: { [weak self] in self?.later() }))
        host.view.backgroundColor = .clear
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        PopSound.play()
    }
}

/// "뽁" — 안내가 뜰 때 한 번(Android `PopSound`, 2026-10-10 사용자). 소리는 Android `res/raw/pop.wav` 그대로(직접 합성,
/// 0.16초). **시스템 사운드**로 내서 무음 스위치를 켜 두면 나지 않는다(Android 는 시스템 소리 볼륨 · 무음 모드를 따름).
enum PopSound {
    nonisolated(unsafe) private static var sound: SystemSoundID = 0

    static func play() {
        if sound == 0 {
            guard let url = Bundle.main.url(forResource: "pop", withExtension: "wav") else { return }
            AudioServicesCreateSystemSoundID(url as CFURL, &sound)
        }
        AudioServicesPlaySystemSound(sound)
    }
}

/// 새 버전 알림 — Android `ui/components/UpdateDialog.kt`. 흰 카드 + 알약 버튼, 맨 위 로고(하트 새싹)로 시스템 경고가 아니라
/// 이 앱이 말하는 것으로 읽히게 한다. 바깥을 누르면 `나중에` 와 같다.
struct UpdateDialog: View {
    var onUpdate: () -> Void
    var onLater: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onLater)
                .accessibilityHidden(true)
            UpdateCard(onUpdate: onUpdate, onLater: onLater).padding(16)
                .scaleEffect(shown ? 1 : 0.96)
        }
        .opacity(shown ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.18)) { shown = true } }
        .accessibilityAction(.escape, onLater)
    }
}

struct UpdateCard: View {
    var onUpdate: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(WPColor.brand100)
                if let logo = UIImage(named: "heart_sprout") {
                    Image(uiImage: logo).resizable().scaledToFit().frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }.frame(width: 64, height: 64)
            Text(UpdateRules.title.wpKeepAll).tracking(-0.38).foregroundColor(WPColor.textPrimary)
                .wpTypography(19, .bold).multilineTextAlignment(.center).padding(.top, 16)
                .accessibilityLabel(UpdateRules.title)
            PassParagraph(text: UpdateRules.body, size: 14.5, lineHeight: 22, color: WPColor.stone600, alignment: .center).padding(.top, 8)
            VStack(spacing: 10) {
                pill(UpdateRules.update, background: WPColor.primary, content: .white, border: nil, action: onUpdate).accessibilityIdentifier("update.confirm")
                pill(UpdateRules.later, background: .white, content: WPColor.stone600, border: WPColor.stone300, action: onLater).accessibilityIdentifier("update.later")
            }.padding(.top, 24)
        }
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 24)
        .frame(maxWidth: 384)
        // 그림자는 카드 면에만 — 안의 버튼·로고에 번지지 않게
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white).shadow(color: .black.opacity(0.18), radius: 20, y: 8))
        // 카드 안쪽 탭이 바깥(닫기)으로 새지 않게
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {}
    }

    private func pill(_ label: String, background: Color, content: Color, border: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).wpTypography(15, .bold).foregroundStyle(content).lineLimit(1).padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(background, in: Capsule())
                .overlay { if let border { Capsule().strokeBorder(border, lineWidth: 1.5) } }
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }
}
