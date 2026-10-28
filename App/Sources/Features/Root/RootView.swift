import SwiftUI
import WPDomain

/// 최상위 화면 전환.
///
/// 웹의 `GuestGate` + `AuthRedirectToMain` 이 하던 일을 여기 한 곳에서 한다.
/// 웹은 주소를 직접 칠 수 있어 화면마다 게이트가 새는 구멍이 있었지만
/// (`/main` 에만 걸었다가 `/calendar` 로 샜다), 앱은 진입이 여기 하나뿐이다.
///
/// | 상태 | 보여 주는 것 |
/// | --- | --- |
/// | 토큰 없음 | ``LandingView`` (들어오는 문) |
/// | 토큰 있고 플랜 미완성 | ``SettingView`` (온보딩 — 남은 질문) |
/// | 토큰 있고 플랜 완성 | ``MainTabShell`` |
/// | 아직 물어보는 중 | 브랜드 화면 |
///
/// **`planComplete == nil` 을 `false` 와 같게 다루지 말 것.** 못 물어본 것을
/// "안 채웠다" 로 읽으면 기존 사용자가 앱을 켤 때마다 온보딩을 본다.
struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @EnvironmentObject private var push: PushService
    @State private var tab: WPTab = .home
    /// 가이드는 **하단 탭바까지 덮어야** 하는데 탭바가 화면 바깥이라,
    /// 오버레이는 여기서 그리고 화면들은 띄우라는 신호만 올려보낸다.
    @StateObject private var guide = GuideController()
    @StateObject private var guideAnchors = GuideAnchors()

    var body: some View {
        Group {
            if !env.authChecked {
                // 토큰을 읽기 전 — 로그인한 사람에게 로그인 화면을 비추지 않는다(HOME-01)
                AuthSplash()
            } else if !env.isAuthenticated {
                LandingView()
            } else if env.planComplete == false {
                // 온보딩은 셸(탭바)을 달지 않는다 — 중간에 홈으로 새면 안 된다.
                SettingView { env.markPlanComplete() }
            } else if env.planComplete == true {
                MainTabShell(tab: $tab)
            } else {
                AuthSplash()
            }
        }
        .environmentObject(guide)
        .environment(\.guideAnchors, guideAnchors)
        .tint(WPColor.primary)
        // 앱이 켜져 있을 때 온 알림은 배너 대신 토스트로 (배너까지 뜨면 두 번 알리는 셈이다).
        .overlay(alignment: .top) {
            if let toast = push.toast {
                PushToast(text: toast) { push.toast = nil }
            }
        }
        // 알림을 눌러 들어온 채팅방.
        .fullScreenCover(item: pushChatBinding) { room in
            ChatView(chatRoomId: room.id)
                .environmentObject(env)
                .environmentObject(push)
        }
        // 공유 링크로 들어오면 어느 화면에 있든 참여 화면이 덮는다 (웹은 `/share/{code}` 페이지).
        .fullScreenCover(item: shareCodeBinding) { pending in
            ShareJoinView(shareCode: pending.code, asSpouse: pending.asSpouse) {
                // 참여 성공 → 참여 플랜 목록 (웹 `router.replace("/plan-list")`)
                env.pendingShareCode = nil
                tab = .home
            } onLoginRequested: {
                env.pendingShareCode = nil
                env.isAuthenticated = false
            } onClose: {
                env.pendingShareCode = nil
            }
            .environmentObject(env)
            .environmentObject(guest)
        }
    }

    private var pushChatBinding: Binding<PendingChatRoom?> {
        Binding(
            get: { push.pendingChatRoomId.map(PendingChatRoom.init(id:)) },
            set: { if $0 == nil { push.pendingChatRoomId = nil } }
        )
    }

    /// `fullScreenCover(item:)` 이 Identifiable 을 요구해서 감싼다.
    private var shareCodeBinding: Binding<PendingShare?> {
        Binding(
            get: {
                // **저장 값에 역할이 함께 실려 있다.** 코드만 읽으면 배우자 초대가
                // 조언자 초대로 조용히 바뀐다.
                env.pendingShareCode
                    .flatMap(ShareLink.Invite.init(storageValue:))
                    .map { PendingShare(code: $0.code, asSpouse: $0.asSpouse) }
            },
            set: { if $0 == nil { env.pendingShareCode = nil } }
        )
    }
}

/// 토큰은 있는데 플랜을 아직 못 물어본 짧은 사이.
///
/// 여기서 홈을 먼저 그리면 온보딩이 필요한 사람에게 빈 화면이 한 번 스쳤다가
/// 바뀐다. 반대로 "일정이 없어요" 같은 빈 상태를 말하지도 않는다 —
/// 아직 아무것도 모르는 상태다.
private struct AuthSplash: View {
    var body: some View {
        ZStack {
            WPColor.background.ignoresSafeArea()
            AppLogo(size: 56)
                .opacity(0.5)
        }
        .accessibilityIdentifier("root.splash")
    }
}

private struct PendingShare: Identifiable, Hashable {
    var code: String
    var asSpouse: Bool
    var id: String { asSpouse ? "\(code)?as=spouse" : code }
}

private struct PendingChatRoom: Identifiable, Hashable {
    var id: Int
}

/// 앱이 켜져 있을 때 온 알림을 위쪽에 잠깐 띄운다.
private struct PushToast: View {
    var text: String
    var onDismiss: () -> Void

    var body: some View {
        Text(text)
            .font(WPFont.hak(14, .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                WPColor.textPrimary.opacity(0.95),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture(perform: onDismiss)
            .task {
                // 3초 뒤 자동으로 사라진다.
                try? await Task.sleep(for: .seconds(3))
                onDismiss()
            }
    }
}

/// 탭 안으로 밀어 넣은 화면 중 **탭바가 없는 화면**이 올리는 요청(안드로이드 `onTabScreen` 에 없는 경로 —
/// 후기 상세 등). iOS 는 탭마다 내비게이션 스택이 탭바 **위**에 있어서, 요청이 없으면 밀어 넣은 화면에도
/// 탭바가 남았습니다. 일정 상세·예산·프로필은 Android 도 탭바를 두므로 요청하지 않습니다.
@MainActor
final class TabBarVisibility: ObservableObject {
    @Published private(set) var hidden = false
    private var requests: Set<UUID> = []
    func hide(_ id: UUID) { requests.insert(id); hidden = !requests.isEmpty }
    func show(_ id: UUID) { requests.remove(id); hidden = !requests.isEmpty }
}

private struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: TabBarVisibility? = nil
}
extension EnvironmentValues {
    /// 탭 셸 밖(테스트·전체 화면 창)에서는 비어 있습니다 — 그때는 숨길 탭바도 없습니다
    var tabBarVisibility: TabBarVisibility? {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

private struct HidesTabBar: ViewModifier {
    @Environment(\.tabBarVisibility) private var tabBar
    @State private var id = UUID()
    func body(content: Content) -> some View {
        content.onAppear { tabBar?.hide(id) }.onDisappear { tabBar?.show(id) }
    }
}

extension View {
    /// 이 화면이 떠 있는 동안 하단 탭바를 숨깁니다(Android 에서 탭바가 없는 화면)
    func wpHidesTabBar() -> some View { modifier(HidesTabBar()) }
}

/// 플랜 추가·수정을 **탭 셸 안에** 여는 요청. Android 는 플랜 추가(`ADD_PLAN`)가 탭바가 있는 화면이라
/// (`AppNavHost.onTabScreen`) 가운데 `+` 는 물론 홈 `추가` · 달력 `+ 플랜 추가` · 상세 `수정하기` · 피드 `담기` 로
/// 열어도 아래 탭바가 남고, 가운데 `+` 가 켜집니다(`TabType.fromRoute(ADD_PLAN) = ADD`).
/// iOS 는 `fullScreenCover` 로 띄워 탭바가 가려졌습니다 — 그래서 셸이 내용 자리에 덮어 그립니다.
struct AddPlanRequest: Identifiable {
    let id = UUID()
    var editId: Int? = nil
    var roomId: Int? = nil
    var initialDate: String? = nil
    var prefill: AddPlanViewModel.Prefill? = nil
    var onSaved: () -> Void = {}
}

@MainActor
final class AddPlanPresenter: ObservableObject {
    @Published private(set) var request: AddPlanRequest?

    /// 셸 위에 열 수 있으면 열고 `true`. **다른 창(시트·전체 화면)이 떠 있으면 `false`** — 그 창 아래에 깔려
    /// 보이지 않으므로 부른 쪽이 예전처럼 자기 창으로 띄웁니다(달력·채팅에서 전체 화면으로 연 일정 상세 등).
    @discardableResult
    func open(_ request: AddPlanRequest) -> Bool {
        guard !Self.somethingPresented else { return false }
        withAnimation(.easeOut(duration: 0.2)) { self.request = request }
        return true
    }

    func close() {
        guard request != nil else { return }
        withAnimation(.easeOut(duration: 0.2)) { request = nil }
    }

    static var somethingPresented: Bool {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        let root = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        return root?.presentedViewController != nil
    }
}

/// 달력·채팅에서 여는 일정 상세 — 셸이 내용 자리 위에 덮어 그려 **탭바가 남습니다**(Android 는 `SCHEDULE_DETAIL`
/// 에도 탭바를 둡니다 — `onTabScreen`). 예전에는 전체 화면 창이라 그 상세와 거기서 연 수정하기에 탭바가 없었습니다.
struct ScheduleDetailRequest: Identifiable {
    let id = UUID()
    var scheduleId: Int
    var roomId: Int?
    var onClose: () -> Void = {}
}

@MainActor
final class ScheduleDetailPresenter: ObservableObject {
    @Published private(set) var request: ScheduleDetailRequest?

    /// 셸 위에 열 수 있으면 열고 `true`. 다른 창이 떠 있으면 `false` — 부른 쪽이 예전처럼 자기 창으로 띄웁니다.
    @discardableResult
    func open(_ request: ScheduleDetailRequest) -> Bool {
        guard !AddPlanPresenter.somethingPresented else { return false }
        withAnimation(.easeOut(duration: 0.2)) { self.request = request }
        return true
    }

    func close() {
        guard let request else { return }
        withAnimation(.easeOut(duration: 0.2)) { self.request = nil }
        request.onClose()
    }
}

private struct ScheduleDetailPresenterKey: EnvironmentKey {
    static let defaultValue: ScheduleDetailPresenter? = nil
}
private struct ScheduleDetailCloseKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}
extension EnvironmentValues {
    /// 탭 셸 안이면 일정 상세를 셸 위에 엽니다(탭바가 남음). 셸 밖에서는 비어 있습니다.
    var scheduleDetailPresenter: ScheduleDetailPresenter? {
        get { self[ScheduleDetailPresenterKey.self] }
        set { self[ScheduleDetailPresenterKey.self] = newValue }
    }
    /// 셸이 덮어 그린 일정 상세의 닫기. 창이 아니라 `dismiss` 가 닿지 않습니다.
    var scheduleDetailClose: (() -> Void)? {
        get { self[ScheduleDetailCloseKey.self] }
        set { self[ScheduleDetailCloseKey.self] = newValue }
    }
}

private struct AddPlanPresenterKey: EnvironmentKey {
    static let defaultValue: AddPlanPresenter? = nil
}
private struct AddPlanCloseKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}
extension EnvironmentValues {
    /// 탭 셸 안이면 플랜 추가·수정을 셸 위에 엽니다(탭바가 남음). 셸 밖(테스트·단독 창)에서는 비어 있습니다.
    var addPlanPresenter: AddPlanPresenter? {
        get { self[AddPlanPresenterKey.self] }
        set { self[AddPlanPresenterKey.self] = newValue }
    }
    /// 셸이 덮어 그린 플랜 추가의 닫기. 창으로 띄운 것이 아니라 `dismiss` 가 닿지 않습니다.
    var addPlanClose: (() -> Void)? {
        get { self[AddPlanCloseKey.self] }
        set { self[AddPlanCloseKey.self] = newValue }
    }
}

/// 웹의 `BottomTabBar` 가 붙은 화면 셸.
///
/// 각 화면이 자기 배경과 상태바 여백을 직접 처리하므로 여기서는 배치만 한다.
struct MainTabShell: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var notifications: InAppNotifications
    @Binding var tab: WPTab
    @State private var revision = UUID()
    @StateObject private var tabBar = TabBarVisibility()
    @StateObject private var addPlan = AddPlanPresenter()
    @StateObject private var detail = ScheduleDetailPresenter()
    /// Android `showTabBar = onTabScreen && !imeVisible` — 키보드가 떠 있으면 탭바를 내린다
    /// (입력이 많은 플랜 추가에서 탭바가 키보드 위로 떠 입력 칸을 가리지 않게. 채팅 입력도 같음).
    @State private var keyboardUp = false

    var body: some View {
        let adding = addPlan.request != nil
        let detailOpen = detail.request != nil
        VStack(spacing: 0) {
            ZStack {
                Group {
                    // 홈(·플랜 추가 위의 홈)은 덮지 않는다 — MainView 가 방을 먼저 묻고 받으며, 받는 동안 뼈대를 낸다(오류면
                    // 스스로 덮고 다시 시도). 여기서 덮으면 앱을 켤 때마다 흰 면 + 스피너가 먼저 보였다(2026-10-28 iOS QA HOME-01).
                    if env.boundRoom.needsCover && tab == .schedule {
                        VStack(spacing: 16) {
                            if let error = env.boundRoomError { Text(error); Button("다시 시도") { Task { await env.refreshBoundRoom() } } }
                            else { ProgressView() }
                        }.task { await env.refreshBoundRoom() }
                    } else {
                    switch tab {
                    case .home, .add: MainView()
                    case .schedule: CalendarView(roomId: env.boundRoomId, showsClose: false)
                    case .rooms: CoupleChatTab()
                    case .explore: ExploreView()
                    }
                    }
                }.id(revision).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.tabBarVisibility, tabBar)
                    .environment(\.addPlanPresenter, addPlan)
                    .environment(\.scheduleDetailPresenter, detail)
                    // 덮인 화면은 보이지 않으니 손쓰기(VoiceOver·UI 테스트)에서도 뺀다
                    .accessibilityHidden(adding || detailOpen)

                if let request = detail.request {
                    ScheduleDetailView(scheduleId: request.scheduleId, roomId: request.roomId)
                        .id(request.id)
                        .environment(\.scheduleDetailClose, { detail.close() })
                        .environment(\.addPlanPresenter, addPlan)
                        .accessibilityHidden(adding)
                        .accessibilityAddTraits(.isModal)
                        .transition(.opacity)
                        .zIndex(0.5)
                }

                if let request = addPlan.request {
                    AddPlanView(editId: request.editId, roomId: request.roomId, initialDate: request.initialDate,
                                prefill: request.prefill, onSaved: request.onSaved)
                        .id(request.id)
                        .environment(\.addPlanClose, { addPlan.close() })
                        // 아래 덮인 화면을 VoiceOver 가 건너뛰게(NavigationStack 안쪽 UIKit 화면에는 accessibilityHidden 이 닿지 않는다)
                        .accessibilityAddTraits(.isModal)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            // 후기 상세처럼 탭바가 없는 화면에서 `담기` 로 열어도 플랜 추가에는 탭바가 있다(Android ADD_PLAN)
            if (adding || detailOpen || !tabBar.hidden) && !keyboardUp {
                BottomTabBar(
                    // 플랜 추가가 떠 있으면 가운데 `+` 가 켜진다 — 다른 탭은 꺼진다(Android `fromRoute(ADD_PLAN) = ADD`)
                    // 일정 상세는 홈이 켜진다(Android `fromRoute(SCHEDULE_DETAIL)` → HOME)
                    active: Binding(get: { adding ? .add : detailOpen ? .home : tab }, set: { tab = $0 }),
                    unreadCount: notifications.unreadCount,
                    onAdd: {
                        // 이미 플랜 추가면 그대로(Android `currentRoute != ADD_PLAN` 일 때만 연다)
                        guard !adding, !env.boundRoom.needsCover else { return }
                        addPlan.open(AddPlanRequest(roomId: env.boundRoomId) { revision = UUID() })
                    },
                    // 다른 탭(같은 탭 포함)을 누르면 플랜 추가는 빠지고 그 탭이 처음부터 열린다(Android popToRoot)
                    onSelect: { addPlan.close(); detail.close(); revision = UUID() }
                )
            }
        }.background(WPColor.background)
            .onChange(of: env.roomsRevision) { _, _ in revision = UUID() }
            /*
              **결제를 마치면 홈으로**(안드로이드 AppNavHost `passPurchased` — 웹: 결제 성공 → `시작하기` → `/main`). 홈이 켜진 패스를
              보여 준다. 소개·요금제 창이 먼저 내려간 뒤에 탭을 다시 만든다(그 아래 띄운 화면들도 함께 닫힌다). 플랜 추가 폼에서는
              옮기지 않는다 — 영수증 칸으로 결제한 사람의 적던 플랜이 저장 전에 사라진다.
            */
            .onChange(of: env.passPurchase) { _, event in
                guard let event, event.goHome else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    guard addPlan.request == nil else { return }
                    detail.close(); tab = .home; revision = UUID()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                // 화면에 올라온 소프트웨어 키보드만 친다 — 하드웨어 키보드의 작은 도구 막대나 화면 밖 프레임은
                // 키보드가 아니다(Android 도 IME 가 화면에 뜰 때만 `isImeVisible`)
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                let screen = (note.object as? UIScreen)?.bounds.height ?? frame.maxY
                keyboardUp = frame.height > 100 && frame.minY < screen - 1
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardUp = false
            }
    }
}
