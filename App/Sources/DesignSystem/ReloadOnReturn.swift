import SwiftUI
import UIKit

/// 안드로이드 `ON_RESUME` 처럼 받는다 — 처음 나타날 때, **밀어 넣은 화면에서 돌아올 때**, **앱이 백그라운드에서 돌아올 때**.
/// 시트 · 전체 화면 창에 가려졌다 돌아올 때는 받지 않는다(안드로이드의 창은 화면의 생명주기를 건드리지 않는다).
///
/// 2026-11-04 결정(안드로이드 요청서 `docs/test-reports/2026-11-04-ios-handoff`, 사용자 "iOS 를 안드로이드처럼"): 한때 "이 기기에서
/// 일정 · 패스 · 방을 바꿨을 때만" 다시 받았는데, 그러면 상대(신랑 · 신부)가 다른 폰에서 고친 것이 돌아와도 안 보였다. 다시 받지
/// 않게 바꾼 까닭이던 "네트워크에 연결할 수 없습니다" 는 취소를 오류로 감싼 버그였고 따로 고쳤다(`Error.isCancellation`).
///
/// - **조용히** 받는 것은 각 화면의 몫이다 — 받아 둔 값이 있으면 뼈대로 바꾸지 않는다(홈 `listLoaded` · 예산 `hadDetail` · 달력 `byDay`).
/// - 첫 받기가 끝나기 전에 떠나 취소됐으면 받은 것으로 치지 않는다 — 창에 가려졌다 돌아와도 다시 받는다(안 그러면 뼈대에 갇힌다).
/// - 창에 가려졌는지는 사라질 때 그 위에 띄운 창이 **새로 생겼는지**로 가린다. 화면 자체가 창 안에 있어도(창 안의 NavigationStack)
///   그 안에서 밀어 넣은 화면은 창이 늘지 않으므로 돌아올 때 받는다.
struct ReloadOnReturn<ID: Equatable>: ViewModifier {
    let id: ID
    let action: () async -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadedOnce = false
    @State private var visible = false
    @State private var depthAtAppear = 0
    @State private var coveredByWindow = false
    @State private var wentToBackground = false
    @State private var loadedID: ID?

    func body(content: Content) -> some View {
        content
            .task(id: id) {
                visible = true
                depthAtAppear = Self.presentationDepth
                let covered = coveredByWindow
                coveredByWindow = false
                // 창을 닫고 돌아온 것이면 받지 않는다 — 같은 대상을 이미 다 받았을 때만
                if covered, loadedOnce, loadedID == id { return }
                await action()
                if !Task.isCancelled { loadedOnce = true; loadedID = id }
            }
            .onDisappear {
                visible = false
                coveredByWindow = Self.presentationDepth > depthAtAppear
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background: wentToBackground = true
                case .active:
                    guard wentToBackground else { return }
                    wentToBackground = false
                    // 보이는 화면만 — 창에 가려진 화면은 창이 닫히며 돌아올 때도 받지 않는다(안드로이드와 같음)
                    if visible, loadedOnce { Task { await action() } }
                default: break
                }
            }
    }

    /// 지금 앱 창 위에 몇 겹의 창(시트 · 전체 화면)이 떠 있는지
    @MainActor static var presentationDepth: Int {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        var vc = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        var depth = 0
        while let next = vc?.presentedViewController { depth += 1; vc = next }
        return depth
    }
}

extension View {
    /// `.task` 대신 — 돌아올 때(밀어 넣은 화면 · 앱 복귀) 조용히 다시 받고, 창을 닫을 때는 받지 않는다(`ReloadOnReturn`).
    func reloadOnReturn(perform action: @escaping () async -> Void) -> some View {
        modifier(ReloadOnReturn(id: 0, action: action))
    }

    /// `id` 가 바뀌면 곧바로 다시 받는다(`.task(id:)` 와 같음).
    func reloadOnReturn<ID: Equatable>(id: ID, perform action: @escaping () async -> Void) -> some View {
        modifier(ReloadOnReturn(id: id, action: action))
    }
}

/// 준비 패스 소개(전체 화면)를 띄우고, **닫았을 때 패스가 바뀌었으면만** `onPassChanged` 를 부른다.
///
/// 예전에는 X 로 닫기만 해도 띄운 화면이 다시 받았다(2026-11-04 사용자 "모달 같은 걸 X 하면 새로고침 되면 안 돼").
/// 결제 · 복원은 `AppEnvironment.passRevision` 을 올리므로 열 때의 값과 견준다.
struct PassCover<Cover: View>: ViewModifier {
    @EnvironmentObject private var env: AppEnvironment
    @Binding var isPresented: Bool
    let onPassChanged: () -> Void
    @ViewBuilder let cover: () -> Cover
    @State private var revisionAtOpen = 0

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, open in if open { revisionAtOpen = env.passRevision } }
            .fullScreenCover(isPresented: $isPresented, onDismiss: {
                if env.passRevision != revisionAtOpen { onPassChanged() }
            }, content: cover)
    }
}

extension View {
    func passCover<Cover: View>(isPresented: Binding<Bool>, onPassChanged: @escaping () -> Void,
                                @ViewBuilder content: @escaping () -> Cover) -> some View {
        modifier(PassCover(isPresented: isPresented, onPassChanged: onPassChanged, cover: content))
    }
}
