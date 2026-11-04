import SwiftUI

/// 화면이 **처음** 나타날 때 받고, 다시 나타날 때는 `key` 가 달라졌을 때만 다시 받는다.
///
/// SwiftUI 의 `.task` 는 화면이 가려질 때(밀어 넣은 상세 · 전체 화면 창) 취소되고 **다시 나타나면 처음부터 다시 돈다.**
/// 그래서 상세에서 그냥 뒤로 오거나 패스 소개를 X 로 닫기만 해도 홈 · 일정 · 예산이 통째로 다시 받았고, 받는 사이 떠나면
/// 그 취소가 "네트워크에 연결할 수 없습니다." 로 남았다(2026-11-04). 받기가 끝나기 전에 떠나 취소됐으면 받은 것으로
/// 치지 않는다 — 돌아오면 다시 받는다(안 그러면 뼈대에 갇힌다).
///
/// 탭을 눌러 화면이 **새로** 만들어지면(셸의 `revision`) 상태가 비므로 다시 받는다 — 안드로이드의 탭 초기화와 같다.
struct ReloadWhenChanged<Key: Equatable>: ViewModifier {
    let key: () -> Key
    let action: () async -> Void
    @State private var loadedKey: Key?

    func body(content: Content) -> some View {
        content.task {
            let current = key()
            guard loadedKey != current else { return }
            await action()
            if !Task.isCancelled { loadedKey = current }
        }
    }
}

extension View {
    /// `.task` 대신 — 다시 나타날 때 바뀐 게 없으면 받지 않는다(`ReloadWhenChanged`).
    func reloadWhenChanged<Key: Equatable>(_ key: @escaping () -> Key, perform action: @escaping () async -> Void) -> some View {
        modifier(ReloadWhenChanged(key: key, action: action))
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
