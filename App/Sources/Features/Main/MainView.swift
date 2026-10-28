import Observation
import SwiftUI
import UIKit
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/main/page.tsx` 의 **폰 트리(`md:hidden`)** 이식 — 시안 C안 01.
/// 안드로이드 `ui/main/MainScreen.kt` 와 같은 화면이다.
///
/// ```
/// [분홍 머리 면]  이름 · 이니셜 아바타 ›
///                 결혼식까지 / N일 남았어요        ← 32pt, 이 화면에서 사람이 보는 값
///                 2026년 11월 14일 (토) · 예식장
///                 ┌ 남은 예산 · 1,400 만 원 · M만 원 중 K만 원 지출·예정  > ┐  ← 면에 걸친 흰 카드
///                 └ (패스 없음) 모바일 청첩장 줄                              ┘
/// (패스 있음) 축하의 정원 카드
/// 이번 주 결제할 것
/// 이번 달에 할 일 N                               추가
///   회색 채움 카드 (체크 · 제목 · 태그 · 날짜 · 금액)  / 비면 새싹 그림
/// 지난 일정 · 그 다음  계획 중 N                   전체
///   날짜 타일 카드
/// ─ 자랑하기 (탭바 바로 위 고정)
/// ```
///
/// - **두 자리에 멈춘다**(안드로이드 `HeadSnap` · 웹 `snap-y snap-mandatory`) — 머리 면이 다 보이는 자리와,
///   머리 면이 상태바 밑까지 빠져 첫 묶음이 상태바 바로 아래 붙는 자리. 목록이 짧아도 그 자리까지 오르게
///   맨 끝을 채운다(`fill`).
/// - 머리 면은 굴리는 0→200pt 동안 위쪽 기준으로 1→0.9 로 줄고, 50→200pt 에 투명도가 1→0.2 로 빠진다.
/// - 머리 면이 지나가면 상태바 뒤에 흰 띠를 깐다(안드로이드 `BrandStatusBar`).
/// - 글자 줄 높이는 Compose 기본(글자 × 1.5) 또는 안드로이드에 적힌 `lineHeight` 를 `wpTypography` 로 맞춘다.
///   Tmoney 굵은 글자는 안드로이드처럼 Regular 파일에 굵기를 합성한다(`HomeTmoneyLabel`).
///
/// 웹 `MOBILE_GUIDE_STEPS` 는 안드로이드에서 앱 내 가이드를 걷어낸(2026-09-24) 뒤로 쓰이지 않지만,
/// 가이드 오버레이가 이 이름을 읽어 남겨 둔다.
let mainGuideSteps: [GuideStep] = [
    GuideStep(
        id: "main-header-info",
        title: "기본 정보",
        description: "신랑신부님의 이름과 D-day, 그리고 함께 관리하는 멤버를 확인할 수 있어요."
    ),
    GuideStep(
        id: "main-budget-card",
        title: "예산 현황",
        description: "전체 예산 대비 현재까지의 지출 현황을 한눈에 파악하세요."
    ),
    GuideStep(
        id: "main-this-month",
        title: "이번 달에 할 일",
        description: "이번 달 안에 해야 할 일만 모아 둡니다. 지난 일정도 여기 맨 위에 남아요.",
        tooltipAbove: true
    ),
    GuideStep(
        id: "main-plan-list",
        title: "그 다음",
        description: "앞으로 할 일과 날짜를 안 정한 일이 이어집니다. 동그라미를 누르면 완료로 바뀌어요.",
        tooltipAbove: true
    ),
    GuideStep(
        id: "main-bottom-nav",
        title: "네비게이션",
        description: "다른 메뉴로 빠르게 이동할 수 있는 하단 메뉴바입니다.",
        tooltipCenter: true
    ),
]

struct MainView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    /// 받아 둔 홈 데이터는 **탭 셸이 들고 있다**(Android: 탭을 오가도 MainViewModel 은 살아 있고 화면 상태만 새로 시작).
    /// 홈이 들고 있으면 둘러보기에 갔다 돌아올 때마다 새로 만들어져 뼈대가 다시 깜빡였다(2026-10-28 iOS QA HOME-07).
    /// 스크롤 · 머리 면 자리는 이 화면의 상태라 탭을 다시 열면 맨 위에서 시작한다.
    @ObservedObject var model: MainViewModel
    @ObservedObject var invitation: InvitationStore
    @State private var path = NavigationPath()
    @State private var showAddPlan = false
    /// 탭 셸 위에 플랜 추가를 연다(탭바가 남음 — Android `ADD_PLAN`). 셸 밖이면 예전처럼 전체 화면.
    @Environment(\.addPlanPresenter) private var addPlanPresenter
    /// `/plan/brag/my` 를 홈이 다시 그릴 때마다 또 부르지 않도록 하나로 들고 있는다.
    @ObservedObject var bragToggle: BragToggleViewModel
    @State private var showInvite = false
    @State private var showPass = false
    @EnvironmentObject private var guide: GuideController

    /// 묶음 기준일. 렌더마다 새로 만들면 묶음이 흔들린다(웹 `todayForBuckets`).
    @State private var today = KstDate.today()

    /// 굴린 거리 — 머리 면의 줄어듦·흰 띠만 읽는다(이 화면 전체가 매 프레임 다시 그려지지 않게 `@Observable`).
    @State private var scroll = HomeScrollState()
    @State private var snapScroll = HomeSnapScrollView()
    /// 머리 면(정원 카드 포함) · 그 아래 내용 · 스크롤 창의 높이 — 두 자리 스냅과 맨 끝 채움을 잰다.
    @State private var headHeight: CGFloat = 0
    @State private var restHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    /// 목록 아래 여백 — 맨 끝 채움을 잴 때도 쓴다(안드로이드 `LIST_BOTTOM_PAD`)
    private let listBottomPad: CGFloat = 24

    var body: some View {
        NavigationStack(path: $path) {
            content
        }
    }

    // MARK: - 판정

    /// 첫 로딩 실패 — 빈 값 대신 뼈대와 '다시 시도' 를 낸다(안드로이드 `loadFailed`)
    private var loadFailed: Bool { model.errorMessage != nil && !model.listLoaded }

    /// 패스를 쓰는 내 방이면 머리 면이 패스 면(분홍→주황)이 된다.
    private var memberPass: Bool { invitation.result?.hasPass == true && env.isMyAdRoom(model.roomIdValue) }

    /// 제목 자리(anchor) — 머리 면이 상태바 밑까지 빠진 자리
    private var snapAnchor: CGFloat { max(0, headHeight - wpStatusBarHeight) }

    /// 목록이 짧아도 anchor 까지 오르게 채울 높이(안드로이드 `fillPx`)
    private var fillHeight: CGFloat {
        guard viewportHeight > 0 else { return 0 }
        return max(0, viewportHeight - wpStatusBarHeight - listBottomPad - restHeight)
    }

    /// 이 높이보다 낮으면 가로 모드 폰으로 보고 고정 요소를 줄인다(안드로이드 `COMPACT_HEIGHT_DP`)
    private var compactHeight: Bool { UIScreen.main.bounds.height < 480 }

    // MARK: - 화면

    private var content: some View {
        let buckets = model.timeBuckets(today: today)

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HomeHeadFade(scroll: scroll) {
                        headBlock
                    }
                    // 크기는 `onGeometryChange` 로 잰다 — iOS 26 에서 스크롤 안 GeometryReader 의 preference 는
                    // 화면 밖 `onPreferenceChange` 까지 올라오지 않았다(재 보니 0).
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headHeight = $0 }
                    // 머리 면이 다음 줄(이번 주 결제할 것)보다 위에 그려진다 — 카드 그림자가 잘리지 않게
                    .zIndex(1)

                    VStack(alignment: .leading, spacing: 0) {
                        rest(buckets)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { restHeight = $0 }

                    // 맨 끝 채움 — 목록이 짧아도 제목 자리(anchor)까지 올라가게. **늘 마지막 줄이다.**
                    Color.clear.frame(height: fillHeight)
                }
                .padding(.bottom, listBottomPad)
                .background(GeometryReader { g in
                    Color.clear.preference(key: HomeScrollOffsetKey.self, value: g.frame(in: .named("main.scroll")).minY)
                })
                // 내용 안에 있어야 바깥 UIScrollView 를 위로 찾아 올라간다
                .background(ScrollViewFinder { snapScroll.view = $0 })
            }
            .coordinateSpace(name: "main.scroll")
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(HomeHeadSnap(anchor: snapAnchor, viewport: viewportHeight, statusBar: wpStatusBarHeight))
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .modifier(HomeScrollReader { y in
                scroll.offset = y
                // 머리 면 구간에서는 빠른 감속으로 두 자리에 **딱** 붙인다(안드로이드 HeadSnap 의 짧은 애니메이션).
                // 기본(normal) 감속은 손을 뗀 뒤 목표 자리까지 오래 미끄러져 "맞춰지는 속도가 느렸다"(2026-10-16 사용자).
                // 목록 구간은 보통 감속 그대로 — 긴 목록을 휙 넘기는 느낌은 유지한다.
                snapScroll.view?.decelerationRate = y < snapAnchor - 0.5 ? .fast : .normal
            })
            .accessibilityIdentifier("main.scroll")

            // 로딩 실패는 목록 자리의 안내가 맡는다 — 같은 말을 두 번 하지 않는다
            if let message = model.errorMessage, !loadFailed {
                InfoBanner(message: message, actionLabel: "닫기") {
                    model.errorMessage = nil
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // 탭바 바로 위 고정 — 낮은 화면이 아닐 때만(웹 `data-home-brag-dock`)
            if model.canBrag && !compactHeight { bragDock }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        // 머리 면이 지나가면 상태바 뒤에 흰 띠 — 첫 줄(이름)이 상태바에 닿는 16pt 에서 바꾼다
        .overlay(alignment: .top) { HomeStatusStrip(scroll: scroll) }
        // 분홍 머리 면이 상태바 뒤까지 깔리도록 스크롤 영역을 위로 넓힌다.
        // 면은 스크롤 영역 **안**에 있어 내용과 함께 올라간다(웹 `data-mobile-head`).
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        // **전환하는 동안 가림막으로 덮는다.** 안 덮으면 방을 묻는 사이에 화면이
        // 이미 내 개인 플랜을 그려서, 개인 플랜이 떴다가 방 플랜으로 바뀌는 게
        // 그대로 보인다. **불투명이어야 한다** — 반투명이면 큰 숫자가 비친다.
        // 아직 아무것도 받지 않았으면(뼈대가 깔려 있음) 덮지 않는다 — 덮으면 앱을 켤 때마다 흰 면 + 스피너가 1초쯤 먼저
        // 보였다(2026-10-28 iOS QA HOME-01, Android 는 받는 동안 뼈대). 덮는 것은 이미 그린 숫자가 있을 때와 오류일 때다.
        .overlay {
            if env.boundRoom.needsCover && (env.boundRoomError != nil || !model.planLoading) {
                ZStack {
                    Color.white.ignoresSafeArea()
                    if let error = env.boundRoomError {
                        VStack(spacing: 16) { Text(error); Button("다시 시도") { Task { await env.refreshBoundRoom(); if !env.boundRoom.needsCover { await model.load(env: env, guest: guest) } } } }
                    } else { ProgressView() }
                }.accessibilityIdentifier("main.boundCover")
            }
        }
        .task {
            today = KstDate.today()
            // 방을 먼저 정하고 목록을 받는다. 순서를 뒤집으면 개인 플랜을 한 번
            // 그린 뒤 방 플랜으로 바뀐다.
            await env.refreshBoundRoom()
            guard !env.boundRoom.needsCover else { return }
            await model.load(env: env, guest: guest)
            await invitation.load(env)
            await env.refreshAdEligibility()
        }
        // 청첩장 칸에서 축하를 읽고 돌아오면 `새 축하 N` 이 다시 받기 전에도 줄어든다(Android `HomeInvitationViewModel`)
        .onAppear { Task { await invitation.countFresh(env) } }
        .navigationDestination(for: Int.self) { scheduleId in
            ScheduleDetailView(scheduleId: scheduleId, roomId: model.roomIdValue)
        }
        .navigationDestination(for: BudgetRoute.self) { route in
            BudgetDetailView(roomId: route.roomId.map(String.init))
        }
        .navigationDestination(for: CalendarRoute.self) { route in
            CalendarView(roomId: route.roomId, readOnly: route.readOnly)
        }
        .navigationDestination(for: BragRoute.self) { _ in
            BragView()
        }
        .fullScreenCover(isPresented: $showPass) { PassView(roomId: model.roomIdValue) }
        .sheet(isPresented: $showInvite) {
            SpouseInviteSheet()
                .environmentObject(env)
        }
        .fullScreenCover(isPresented: $showAddPlan) {
            AddPlanView(roomId: model.roomIdValue) {
                Task { await model.load(env: env, guest: guest) }
            }
            .environmentObject(env)
            .environmentObject(guest)
        }
    }

    private func startAdd() {
        let opened = addPlanPresenter?.open(AddPlanRequest(roomId: model.roomIdValue) {
            Task { await model.load(env: env, guest: guest) }
        }) ?? false
        if !opened { showAddPlan = true }
    }

    /// 머리 면 + (패스를 산 사람의) 정원 카드. 안드로이드는 둘이 **같은 목록 줄**이라 두 자리 스냅이
    /// 정원 카드까지 한 칸으로 잰다 — 그래서 여기서도 함께 잰다.
    private var headBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            if (invitation.homeState == .empty || invitation.homeState == .mine), env.isMyAdRoom(model.roomIdValue), !model.isGuest {
                HomeInvitationEntry(
                    model: invitation,
                    planDate: model.weddingDate?.dateString,
                    planVenue: model.weddingVenue.isEmpty ? nil : model.weddingVenue
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private func rest(_ buckets: (thisMonth: [ScheduleItem], past: [ScheduleItem], later: [ScheduleItem])) -> some View {
        /*
          이번 주 결제할 것 — **이번 달 목록보다 위**다. 돈이 곧 나갈 일이 이번 달 전체보다 급하다.
          해당 일정이 없으면 띠 자체가 안 나온다("0건" 빈 카드를 만들지 않는다).
        */
        if !model.planLoading && !loadFailed && !model.isGuest {
            PayThisWeekView(schedules: model.planned + model.completed, today: today,
                roomId: model.roomIdValue,
                showReminder: !model.isRoomView || ["OWNER", "SPOUSE"].contains(model.myPermission?.rawValue.uppercased() ?? ""),
                onSelect: { path.append($0) })
        }

        HomeSectionHeader(
            title: "이번 달에 할 일",
            meta: (model.planLoading || loadFailed) ? nil : "\(buckets.thisMonth.count)",
            // READ 권한이면 추가를 감춘다 — **눌러야만 실패를 아는 버튼은 두지 않는다.**
            // 방을 모르는 동안(로딩 실패)에도 감춘다 — 어디에 저장될지 모른다.
            actionLabel: model.canWrite && !loadFailed ? "추가" : nil,
            onAction: { startAdd() }
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .guideAnchor("main-this-month")

        listSection(buckets)
            .guideAnchor("main-plan-list")

        // 웹: 비로그인일 때만 목록 아래에 노출
        if model.isGuest {
            LoginButton { env.isAuthenticated = false }
                .padding(.horizontal, 16)
                .padding(.top, 16)
        }

        // 낮은 화면에서는 도크를 목록 끝에(가로 폰에서 고정 도크 + 탭바가 화면의 절반을 넘었다)
        if model.canBrag && compactHeight {
            bragDock.padding(.top, 16)
        }
    }

    /// 웹 `BottomTabBar aboveTabs` 의 `data-home-brag-dock` — `border-t border-[#f2eaee] bg-white px-4 py-3`
    private var bragDock: some View {
        VStack(spacing: 0) {
            Color(hex: 0xF2EAEE).frame(height: 1)
            BragToggle(model: bragToggle, onOpenBrag: { path.append(BragRoute()) }, locked: model.bragLocked, compact: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(Color.white)
        // 도크는 제 높이만 — 남는 높이를 목록과 나눠 가지지 않게
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 머리 면

    private var head: some View {
        BrandHead(bottom: 0, overhang: 72, passMember: memberPass) {
            HStack(spacing: 0) {
                // 이름·아바타가 남는 폭을 쓰고, 배지는 늘 오른쪽 끝에 붙는다.
                // 내 홈이면 이름·아바타가 프로필로 가는 길이다(하단 탭에서 빠졌다).
                // **받는 중·실패여도 눌린다** — 프로필(로그아웃·탈퇴·차단 관리)로 가는 유일한 길이다.
                if model.planLoading && !loadFailed {
                    SkeletonBox(width: 110, height: 22, onBrand: true)
                } else {
                    NavigationLink { UserView() } label: {
                        HStack(spacing: 0) {
                            HomeTmoneyLabel(
                                runs: [.init(loadFailed ? "내 프로필" : (model.displayName.isEmpty ? "이름" : model.displayName), size: 18, tracking: -0.36)],
                                color: .white,
                                lineHeight: 27
                            )
                            Spacer().frame(width: 8)
                            HeadAvatars(initials: model.headerInitials)
                            // 눌린다는 표시 — 프로필 탭이 없어져 이 줄이 그 자리를 대신한다
                            WPLucideIcon(paths: WPIconPaths.chevronRight, size: 18, color: .white.opacity(0.75))
                                .padding(.leading, 2)
                        }
                        // 보이는 줄은 안드로이드처럼 27pt, 누르는 자리만 위아래로 넓힌다
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .padding(.vertical, -8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("내 정보")
                    .accessibilityIdentifier("main.profile")
                }
                Spacer(minLength: 0)
                // 웹 폰 트리에는 초대 아이콘이 없다 — 초대는 아래 초대 띠가 맡는다. 패스를 쓰는 방이면 노란 배지.
                if memberPass {
                    Spacer().frame(width: 8)
                    HStack(spacing: 4) {
                        // 안드로이드 `PassMemberBadge` — Material `Icons.Outlined.LocalFlorist`
                        WPMaterialPathIcon(paths: HomeColor.florist, size: 13, color: Color(hex: 0x875022))
                        Text("준비 패스").font(WPFont.hak(9, .bold))
                        WPMaterialPathIcon(paths: WPIconPaths.check, size: 10, color: Color(hex: 0x875022))
                    }.foregroundStyle(Color(hex: 0x875022)).padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color(hex: 0xFFF1B8), in: Capsule())
                }
            }
            .guideAnchor("main-header-info")

            if model.planLoading || loadFailed {
                Spacer().frame(height: 16)
                SkeletonBox(width: 240, height: 74, onBrand: true)
                Spacer().frame(height: 8)
                SkeletonBox(width: 190, height: 16, onBrand: true)
            } else {
                let sentence = model.dDaySentence
                Spacer().frame(height: 16)
                Text("\(sentence.0)\n\(sentence.1)")
                    .font(WPFont.hak(32, .bold))
                    .tracking(-1.44)
                    .foregroundStyle(.white)
                    .lineSpacing(0)
                    .fixedSize(horizontal: false, vertical: true)
                    // 안드로이드 `lineHeight = 37.sp` 두 줄 = 74
                    .frame(height: 74, alignment: .leading)

                Spacer().frame(height: 8)
                Text(subtitleText)
                    .wpTypography(14)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            // 온보딩에서 초대를 건너뛴 자리 — 배우자가 들어오면 사라진다.
            if model.showSoloBanner && !model.planLoading {
                Spacer().frame(height: 16)
                SoloPlanBanner { showInvite = true }
            }

            Spacer().frame(height: 16)
            budgetCard
                .guideAnchor("main-budget-card")
        }
    }

    /// 홈 예산 카드 — 분홍 면 아래 가장자리에 걸쳐 뜬 흰 카드(안드로이드 `BudgetCard`).
    /// 넘었으면 **넘은 금액**(양수)을 `예산 초과` 와 빨강으로 — `-500만 원` 을 크게 세우지 않는다.
    /// 받는 동안은 **같은 크기**의 뼈대(받는 순간 아래 목록이 튀지 않게). 흰 카드 위라 회색 시머다.
    private var budgetCard: some View {
        let loading = model.planLoading || loadFailed || !model.amountsLoaded
        let over = model.remainingBudget < 0
        let ink = over ? HomeColor.over : WPColor.textPrimary
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 0) {
            Button { path.append(BudgetRoute(roomId: model.roomIdValue)) } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        if loading {
                            SkeletonBox(width: 64, height: 18)
                            Spacer().frame(height: 4)
                            SkeletonBox(width: 144, height: 32)
                            Spacer().frame(height: 8)
                            SkeletonBox(width: 208, height: 18)
                        } else {
                            Text(over ? "예산 초과" : "남은 예산")
                                .wpTypography(13, .bold, lineHeight: 18)
                                .foregroundStyle(HomeInviteColor.muted)
                            Spacer().frame(height: 4)
                            HomeTmoneyLabel(
                                runs: [
                                    // 숫자와 `만 원` 사이는 안드로이드 `Spacer(4.dp)`
                                    .init(withThousands(abs(model.remainingBudget)), size: 32, tracking: -0.045 * 32, trailingGap: 4),
                                    .init("만 원", size: 15, tracking: -0.3),
                                ],
                                color: UIColor(ink),
                                lineHeight: 32
                            )
                            Spacer().frame(height: 8)
                            Text("\(withThousands(model.totalBudget))만 원 중 \(withThousands(model.usedBudget))만 원 지출·예정".wpKeepAll)
                                .wpTypography(12.5, lineHeight: 18)
                                .foregroundStyle(HomeInviteColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("\(withThousands(model.totalBudget))만 원 중 \(withThousands(model.usedBudget))만 원 지출·예정")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !loading {
                        Spacer().frame(width: 12)
                        WPLucideIcon(paths: WPIconPaths.chevronRight, size: 20, color: HomeInviteColor.chevron)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(loading)
            .accessibilityIdentifier("main.budget")
            // 패스 없음 — 예산 카드 안의 한 줄. 예산 줄과 따로 눌린다
            if !model.isGuest {
                HomeInvitationEntry(model: invitation, rowOnly: true)
            }
        }
        .background(Color.white, in: shape)
        .clipShape(shape)
        // 안드로이드 `shadow(10.dp, HomeBudgetShadow)` — 따뜻한 잉크로 옅게 번지게
        .shadow(color: Color(hex: 0x1B0D14).opacity(0.08), radius: 10, y: 6)
    }

    private var subtitleText: String {
        var text = model.weddingDate?.weddingDateText ?? ""
        if !model.weddingVenue.isEmpty {
            text += text.isEmpty ? model.weddingVenue : " · \(model.weddingVenue)"
        }
        // 빈 문자열이면 줄이 사라져 아래가 튀므로 공백 한 칸을 남긴다.
        return text.isEmpty ? " " : text
    }

    // MARK: - 목록

    @ViewBuilder
    private func listSection(_ buckets: (thisMonth: [ScheduleItem], past: [ScheduleItem], later: [ScheduleItem])) -> some View {
        // 빈 자리의 `플랜 추가하기` — 머리글의 `추가` 와 같은 조건(읽기 전용·방을 모를 때는 없음)
        let addFromEmpty: (() -> Void)? = model.canWrite && !loadFailed ? { startAdd() } : nil
        let lowScreen = UIScreen.main.bounds.height <= 639

        if model.planLoading {
            // 받기 전에 "없다" 고 말하지 않는다 — 빈 상태 대신 뼈대를 낸다.
            ForEach(0..<5, id: \.self) { _ in SkeletonCard() }
        } else if loadFailed {
            LoadFailed(message: model.errorMessage) {
                model.errorMessage = nil
                Task { await model.load(env: env, guest: guest) }
            }
        } else if model.planned.isEmpty {
            // 예정 플랜이 없으면(완료 기록과 관계없이) 빈 자리. 웹의 `텅~` 대신 새싹이 자라는 그림과
            // `플랜 추가하기` 로 첫 플랜을 권한다(안드로이드 2026-10-07 — **웹과 다름**).
            PlanSproutEmpty(
                title: addFromEmpty == nil ? "아직 플랜이 없어요"
                    : (model.completed.isEmpty ? "첫 플랜을 심어 볼까요?" : "남은 플랜을 다 끝냈어요"),
                onAdd: addFromEmpty,
                lowScreen: lowScreen
            )
        } else {
            ForEach(buckets.thisMonth) { item in
                TaskCard(
                    item: item,
                    toggling: model.togglingIds.contains(item.id),
                    onToggle: { Task { await model.toggle(item, env: env) } },
                    onOpen: { path.append(item.id) }
                )
            }

            if buckets.thisMonth.isEmpty {
                // 다른 달 일정은 아래 묶음에 있고 이번 달만 비었다 — 같은 새싹 그림을 줄여서 권한다.
                PlanSproutEmpty(title: "이번 달 할 일이 아직 없어요", onAdd: addFromEmpty, lowScreen: lowScreen, compact: true)
            }

            // 광고 ① — 「이번 달에 할 일」 블록 다음 한 칸(광고 담당이 자리를 정한다).
            if AdRules.homeAdVisible(gate: env.adGate, isMyPlan: env.isMyAdRoom(model.roomIdValue) && !model.isGuest,
                                      thisMonthCount: buckets.thisMonth.count,
                                      hasMoreBelow: !buckets.past.isEmpty || !buckets.later.isEmpty), model.errorMessage == nil {
                // 안드로이드 `MainScreen` 과 같은 바깥 여백(위 14 · 아래 6). 받기 전에는 여백도 없다(NativeAdSlot).
                NativeAdSlot(placement: "home", style: .home, top: 14, bottom: 6)
            }

            // 웹과 같은 두 묶음 — `지난 일정`(지난달까지 못 끝낸 것), `그 다음`(다음 달 이후·날짜 미정).
            // 줄은 날짜 타일 카드(`PlanDateTileItem`)다.
            ForEach(0..<2, id: \.self) { index in
                let title = index == 0 ? "지난 일정" : "그 다음"
                let items = index == 0 ? buckets.past : buckets.later
                if !items.isEmpty {
                    HomeSectionHeader(
                        title: title,
                        // 묶음마다 자기 개수만 — 전체 완료 수를 두 묶음에 똑같이 붙이던 것을 웹(f6f0405)처럼 뺐다
                        meta: "계획 중 \(items.count)",
                        actionLabel: "전체",
                        onAction: {
                            path.append(CalendarRoute(roomId: model.roomIdValue, readOnly: model.readOnly))
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    ForEach(items) { item in
                        HomeDateTileRow(item: item) { path.append(item.id) }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }
                }
            }
        }
    }
}

// MARK: - 라우트

struct BudgetRoute: Hashable {
    var roomId: Int?
}

struct CalendarRoute: Hashable {
    var roomId: Int?
    var readOnly: Bool
}

/// 자랑하기 목록. **레일에만 있고 하단 탭바에는 없다** — 폰에는 레일이 없으므로 홈의 토글 아래
/// `보러 가기` 줄이 유일한 문이다.
struct BragRoute: Hashable {}

// MARK: - 굴림 · 두 자리 스냅

/// 홈 ScrollView 의 바탕 UIScrollView — 머리 면 구간의 감속 속도를 바꾸려고 잡아 둔다(SwiftUI 에 API 가 없다).
private final class HomeSnapScrollView {
    weak var view: UIScrollView?
}

/// 붙은 자리에서 가장 가까운 바깥 UIScrollView 를 찾아 넘긴다.
private struct ScrollViewFinder: UIViewRepresentable {
    let found: (UIScrollView) -> Void
    func makeUIView(context: Context) -> UIView { FinderView(found: found) }
    func updateUIView(_ uiView: UIView, context: Context) {}
    private final class FinderView: UIView {
        let found: (UIScrollView) -> Void
        init(found: @escaping (UIScrollView) -> Void) { self.found = found; super.init(frame: .zero); isUserInteractionEnabled = false }
        required init?(coder: NSCoder) { fatalError() }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var node = superview
            while let current = node {
                if let scroll = current as? UIScrollView { found(scroll); return }
                node = current.superview
            }
        }
    }
}

@Observable
private final class HomeScrollState {
    var offset: CGFloat = 0
}

private struct HomeScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 굴린 거리. iOS 18 부터는 스크롤 뷰가 직접 알려 주는 값을 쓴다 — 내용 안의 GeometryReader 기준은
/// 굴리는 동안 갱신되지 않을 때가 있었다.
private struct HomeScrollReader: ViewModifier {
    let onChange: (CGFloat) -> Void
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in onChange(y) }
        } else {
            content.onPreferenceChange(HomeScrollOffsetKey.self) { onChange(-$0) }
        }
    }
}

/// 안드로이드 `HeadSnap` — 두 자리(0 · anchor = 머리 면 높이 − 상태바)를 지킨다.
///
/// - 머리 면 구간(anchor 이하)에서 시작한 끌기는 anchor 를 못 넘고, 놓으면 굴린 방향·가까운 쪽으로 간다.
/// - 목록에서 올라오는 굴림은 anchor 에서 한 번 선다.
/// - 머리 면이 창보다 크면(가로 · 큰 글꼴) 머리 면 구간은 붙지 않는다.
private struct HomeHeadSnap: ScrollTargetBehavior {
    /// Android `SNAP_VELOCITY = 300.dp`(초당)
    static let snapVelocity: CGFloat = 300
    var anchor: CGFloat
    var viewport: CGFloat
    var statusBar: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard anchor > 1, viewport <= 0 || anchor + statusBar < viewport else { return }
        let y = target.rect.minY
        // `originalTarget` 은 끌기를 시작한 자리다
        let start = context.originalTarget.rect.minY
        let atAnchor = abs(start - anchor) <= 0.5
        if start > anchor + 0.5 || (atAnchor && y >= anchor) {
            // 목록 구간 — 자유롭게 구르되, 위로 올라오는 굴림은 anchor 에서 한 번 선다
            if y < anchor { target.rect.origin.y = anchor }
            return
        }
        // 머리 면 구간 — anchor 를 못 넘고, 놓을 때 **빠르게** 굴렸으면 그 방향, 아니면 가까운 쪽으로 간다(Android
        // `headSnapTarget`, 300dp/s). 예전에는 놓은 뒤 멈출 자리를 시작 자리와 비교해, 천천히 조금만(화면 1/5) 끌어도 위로
        // 움직였으니 제목 자리로 붙었다(2026-10-28 iOS QA HOME-03 — 기대는 맨 위로 되돌아감).
        if y >= anchor { target.rect.origin.y = anchor; return }
        let velocity = context.velocity.dy
        if velocity > Self.snapVelocity { target.rect.origin.y = anchor }
        else if velocity < -Self.snapVelocity { target.rect.origin.y = 0 }
        else { target.rect.origin.y = target.rect.minY * 2 >= anchor ? anchor : 0 }
    }
}

/// 웹 `headerScale`·`headerOpacity` — 굴리는 0→200pt 에 1→0.9 로 **위쪽을 기준으로** 줄고,
/// 50→200pt 에 투명도가 1→0.2 로 빠진다. 굴린 값은 **여기서만** 읽는다(화면 전체가 매 프레임 다시 그려지지 않게).
private struct HomeHeadFade<Content: View>: View {
    let scroll: HomeScrollState
    let content: Content

    init(scroll: HomeScrollState, @ViewBuilder content: () -> Content) {
        self.scroll = scroll
        self.content = content()
    }

    var body: some View {
        let y: CGFloat = max(0, scroll.offset)
        let scale: CGFloat = 1 - 0.1 * min(1, y / 200)
        let fade: CGFloat = min(1, max(0, (y - 50) / 150))
        let alpha: Double = Double(1 - 0.8 * fade)
        content
            .scaleEffect(scale, anchor: .top)
            .opacity(alpha)
    }
}

/// 안드로이드 `BrandStatusBar` — 머리 면이 지나간 뒤 상태바 뒤의 흰 띠
private struct HomeStatusStrip: View {
    let scroll: HomeScrollState
    var body: some View {
        if scroll.offset > 16 {
            BrandStatusStrip()
        }
    }
}

// MARK: - 색 · 글자

/// 안드로이드 `WpColors.HomeBudgetOver` 등 — 홈에서만 쓰는 값
private enum HomeColor {
    static let over = Color(hex: 0xE5484D)
    static let mismatchText = Color(hex: 0x05795F)
    static let mismatchBackground = Color(hex: 0xEEF6F2)
    static let tileBorder = Color(hex: 0xEEE8ED)
    static let tileFill = Color(hex: 0xFFF0F7)
    static let tileMutedFill = Color(hex: 0xF4F2F5)
    static let tileInk = Color(hex: 0xC1367C)
    static let tileMutedInk = Color(hex: 0xA799A5)
    static let tileDoneTitle = Color(hex: 0x91818B)
    static let tileCategory = Color(hex: 0xBF2E77)
    static let tileStatus = Color(hex: 0x958791)
    static let tileNoAmount = Color(hex: 0x9A8D97)
    static let sproutStem = Color(hex: 0xE05A96)
    static let sproutLeafLight = Color(hex: 0xFF8FB8)
    static let ghostLine = Color(hex: 0xE3DDE0)
    static let ghostMark = Color(hex: 0xD9D4D7)
    static let ghostBar = Color(hex: 0xEBE7E9)
    /// Material `Icons.Outlined.LocalFlorist`(준비 패스 배지)
    static let florist = ["M8.66 13.07c.15 0 .29-.01.43-.03C9.56 14.19 10.69 15 12 15s2.44-.81 2.91-1.96c.14.02.29.03.43.03 1.73 0 3.14-1.41 3.14-3.14 0-.71-.25-1.39-.67-1.93.43-.54.67-1.22.67-1.93 0-1.73-1.41-3.14-3.14-3.14-.15 0-.29.01-.43.03C14.44 1.81 13.31 1 12 1s-2.44.81-2.91 1.96c-.14-.02-.29-.03-.43-.03-1.73 0-3.14 1.41-3.14 3.14 0 .71.25 1.39.67 1.93-.43.54-.67 1.22-.67 1.93 0 1.73 1.41 3.14 3.14 3.14zM12 13c-.62 0-1.12-.49-1.14-1.1l.12-1.09c.32.12.66.19 1.02.19s.71-.07 1.03-.19l.11 1.09c-.02.61-.52 1.1-1.14 1.1zm3.34-1.93c-.24 0-.46-.07-.64-.2l-.81-.57c.55-.45.94-1.07 1.06-1.79l.88.38c.4.18.66.59.66 1.03 0 .63-.51 1.15-1.15 1.15zm-.65-4.43c.2-.13.41-.2.64-.2.63 0 1.14.51 1.14 1.14 0 .44-.25.85-.66 1.03l-.88.38c-.12-.72-.51-1.34-1.06-1.79l.82-.56zM12 3c.62 0 1.12.49 1.14 1.1l-.11 1.09C12.71 5.07 12.36 5 12 5s-.7.07-1.02.19l-.12-1.09c.02-.61.52-1.1 1.14-1.1zM8.66 4.93c.24 0 .46.07.64.2l.81.56c-.55.45-.94 1.07-1.06 1.79l-.88-.38c-.4-.17-.66-.58-.66-1.02 0-.63.52-1.15 1.15-1.15zM8.17 9.9l.88-.38c.12.72.51 1.34 1.06 1.79l-.81.56c-.18.13-.41.2-.64.2-.63 0-1.14-.51-1.14-1.14-.01-.44.25-.85.65-1.03zM12 22c4.97 0 9-4.03 9-9-4.97 0-9 4.03-9 9zm2.44-2.44c.71-1.9 2.22-3.42 4.12-4.12-.71 1.9-2.22 3.41-4.12 4.12zM3 13c0 4.97 4.03 9 9 9 0-4.97-4.03-9-9-9zm2.44 2.44c1.9.71 3.42 2.22 4.12 4.12-1.9-.71-3.41-2.22-4.12-4.12z"]
}

/// 안드로이드 `Tmoney` + `FontWeight.Bold` — Regular 파일 하나에 굵기를 **합성**한 글자.
/// 크기가 다른 조각(`2,850` + ` 만 원`)을 한 줄에 기준선으로 맞춰 그린다. 취소선도 받는다(완료 카드).
private struct HomeTmoneyLabel: UIViewRepresentable {
    struct Run: Equatable {
        var text: String
        var size: CGFloat
        var tracking: CGFloat = 0
        /// 다음 조각과의 간격 — 마지막 글자의 자간에 더한다
        var trailingGap: CGFloat = 0
        init(_ text: String, size: CGFloat, tracking: CGFloat = 0, trailingGap: CGFloat = 0) {
            self.text = text; self.size = size; self.tracking = tracking; self.trailingGap = trailingGap
        }
    }
    var runs: [Run]
    var color: UIColor
    var lineHeight: CGFloat
    var bold = true
    var strike = false

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let text = NSMutableAttributedString()
        for run in runs {
            let piece = NSMutableAttributedString(string: run.text, attributes: [
                .font: WPTypeface.tmoney.uiFont(run.size, .regular),
                .foregroundColor: color,
                .strokeColor: color,
                .strokeWidth: bold ? -2.5 : 0,
                .kern: run.tracking,
                .strikethroughStyle: strike ? NSUnderlineStyle.single.rawValue : 0,
            ])
            if run.trailingGap > 0, piece.length > 0 {
                piece.addAttribute(.kern, value: run.tracking + run.trailingGap, range: NSRange(location: piece.length - 1, length: 1))
            }
            text.append(piece)
        }
        label.attributedText = text
        label.accessibilityLabel = runs.map(\.text).joined()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let natural = uiView.intrinsicContentSize.width
        let width = proposal.width.map { min($0, natural) } ?? natural
        return CGSize(width: width, height: lineHeight)
    }
}

/// 묶음 머리글 — 안드로이드 `SectionHeader`(제목 18 굵게 · 개수 13 · 오른쪽 분홍 글자 버튼, 아래 맞춤).
/// 공용 `SectionHeader` 는 SwiftUI 기본 줄 높이라 안드로이드보다 낮아 이 화면에서는 따로 둔다.
private struct HomeSectionHeader: View {
    var title: String
    var meta: String?
    var actionLabel: String?
    var onAction: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(title)
                .wpTypography(18, .bold)
                .tracking(-0.36)
                .foregroundStyle(WPColor.fgNeutral)
            if let meta, !meta.isEmpty {
                Text(meta)
                    .wpTypography(13)
                    .foregroundStyle(WPColor.fgSubtle)
                    .padding(.bottom, 2)
            }
            Spacer(minLength: 0)
            if let actionLabel {
                Button(action: onAction) {
                    Text(actionLabel)
                        .wpTypography(13, .bold)
                        .foregroundStyle(WPColor.primary)
                        .padding(2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(actionLabel == "추가" ? "main.add" : "main.all")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 머리 면 조각

/// 웹 `headerAvatars` — 최대 두 개의 이니셜.
/// 왕관·하트 배지는 달지 않는다 — 26pt 위에서 안 읽히고, 누가 방장인지는 멤버 목록이 말한다.
private struct HeadAvatars: View {
    var initials: [String]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(initials.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(WPFont.hak(11, .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.2), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 2))
            }
        }
    }
}

// MARK: - 카드

/// 시안 C안 01 의 카드 — SEED 채움 카드 `rounded-2xl bg-[#f7f8f9] p-4`, 그림자 없음.
/// 카테고리는 태그가, 언제인지는 날짜와 묶음 머리글이 말한다.
private struct TaskCard: View {
    var item: ScheduleItem
    var toggling: Bool
    var onToggle: () -> Void
    var onOpen: () -> Void

    private var checked: Bool { item.status?.isCompleted ?? false }
    private var dateLabel: String {
        KstDate(dateString: item.startDate ?? "")?.monthDayWeekText ?? "날짜 미정"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 체크는 진짜 Button 이라 카드의 탭 제스처보다 먼저 먹는다.
            // 카드를 Button 으로 감싸면 둘 다 눌려 상세가 같이 열린다.
            CheckCircle(checked: checked, enabled: !toggling, action: onToggle)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HomeTmoneyLabel(
                    runs: [.init(item.title, size: 16, tracking: -0.16)],
                    color: UIColor(checked ? WPColor.fgSubtle : WPColor.fgNeutral),
                    lineHeight: 24,
                    strike: checked
                )

                HStack(spacing: 0) {
                    if !item.categoryName.isEmpty {
                        HomeCategoryTag(name: item.categoryName)
                        Spacer().frame(width: 8)
                    }
                    // 결제가 완료와 어긋날 때만(웹 폰 홈 카드와 같음)
                    if let mismatch = item.paymentMismatch {
                        HomeMismatchBadge(label: mismatch.label, size: 11)
                        Spacer().frame(width: 8)
                    }
                    Text(dateLabel)
                        .wpTypography(13)
                        .foregroundStyle(WPColor.fgMuted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(width: 8)
                    HomeAmountText(amount: Double(item.amount ?? 0))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(checked ? 0.7 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityIdentifier("main.task.\(item.id)")
    }
}

/// 안드로이드 `CategoryTag` — 11 굵게(줄 16.5) · `#fff1f7` · 모서리 4
private struct HomeCategoryTag: View {
    var name: String
    var body: some View {
        Text(name)
            .wpTypography(11, .bold)
            .foregroundStyle(WPColor.brand700)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(WPColor.brand100, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// 안드로이드 `PaymentMismatchBadge` — 결제가 완료와 어긋날 때만(`결제함` · `미결제`)
private struct HomeMismatchBadge: View {
    var label: String
    var size: CGFloat
    var body: some View {
        Text(label)
            .wpTypography(size, .bold)
            .foregroundStyle(HomeColor.mismatchText)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(HomeColor.mismatchBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// 웹: 금액이 있으면 `14px bold #1a1c20`, 없으면 `13px #868b94` "미정"
private struct HomeAmountText: View {
    var amount: Double
    var body: some View {
        if amount > 0 {
            Text("\(withThousands(amount))만 원")
                .wpTypography(14, .bold)
                .foregroundStyle(WPColor.fgNeutral)
                .lineLimit(1)
                .fixedSize()
        } else {
            Text("미정")
                .wpTypography(13)
                .foregroundStyle(WPColor.fgSubtle)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// 웹 `app/components/PlanDateTileItem.tsx` — 날짜 타일 + 제목 · 칩 · 상태 + 금액(안드로이드 `DateTileRow`).
/// `min-h-20 rounded-[15px] border-[#eee8ed] bg-white px-3 py-3 gap-3`
private struct HomeDateTileRow: View {
    var item: ScheduleItem
    var onOpen: () -> Void

    var body: some View {
        let date = KstDate(dateString: item.startDate ?? "")
        let completed = item.status?.isCompleted ?? false
        let amount = Double(item.amount ?? 0)
        let muted = completed || date == nil
        let ink = muted ? HomeColor.tileMutedInk : HomeColor.tileInk
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)

        HStack(spacing: 12) {
            // 날짜 타일 `min-h-14 w-11 rounded-[10px] py-1 text-[10px]` — 세로로 꽉 찬다(self-stretch)
            VStack(spacing: 0) {
                Text(date.map { "\($0.month)월" } ?? "날짜")
                    .wpTypography(10, lineHeight: 15)
                    .foregroundStyle(ink)
                HomeTmoneyLabel(
                    runs: [.init(date.map { String(format: "%02d", $0.day) } ?? "—", size: 21)],
                    color: UIColor(ink),
                    lineHeight: 21
                )
                .fixedSize()
                .padding(.vertical, 2)
                if date == nil {
                    Text("미정").wpTypography(10, lineHeight: 15).foregroundStyle(ink)
                }
            }
            .padding(.vertical, 4)
            .frame(width: 44)
            .frame(minHeight: 56, maxHeight: .infinity)
            .background(muted ? HomeColor.tileMutedFill : HomeColor.tileFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HomeTmoneyLabel(
                    runs: [.init(item.title, size: 15)],
                    color: UIColor(completed ? HomeColor.tileDoneTitle : WPColor.fgNeutral),
                    lineHeight: 20.6
                )
                HStack(spacing: 0) {
                    if !item.categoryName.isEmpty {
                        Text(item.categoryName)
                            .wpTypography(10, lineHeight: 12.5)
                            .foregroundStyle(HomeColor.tileCategory)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(HomeColor.tileFill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Spacer().frame(width: 6)
                    }
                    Text(completed ? "완료" : (date != nil ? "예정" : "계획 중"))
                        .wpTypography(11)
                        .foregroundStyle(HomeColor.tileStatus)
                    if let mismatch = item.paymentMismatch {
                        HomeMismatchBadge(label: mismatch.label, size: 10)
                            .padding(.leading, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if amount > 0 {
                HomeTmoneyLabel(runs: [.init("\(withThousands(amount))만 원", size: 16)], color: UIColor(WPColor.fgNeutral), lineHeight: 24)
                    .fixedSize()
            } else {
                Text("금액 미정")
                    .wpTypography(13)
                    .foregroundStyle(HomeColor.tileNoAmount)
                    .fixedSize()
            }
        }
        .padding(12)
        .frame(minHeight: 80)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white, in: shape)
        .overlay(shape.strokeBorder(HomeColor.tileBorder, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("main.later.\(item.id)")
    }
}

/// 실제 카드와 **같은 짜임**의 뼈대 — 받는 순간 카드 모양·높이가 바뀌지 않게.
private struct SkeletonCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SkeletonBox(width: 22, height: 22, corner: 11)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBox(width: 180, height: 18)
                HStack {
                    SkeletonBox(width: 120, height: 18)
                    Spacer(minLength: 8)
                    SkeletonBox(width: 56, height: 18)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

/// 첫 로딩이 실패했을 때 목록 자리. '텅~' 처럼 **없다고** 말하지 않고, 불러오지 못했다고
/// 말한 뒤 다시 시도할 길을 둔다(안드로이드 `LoadFailed`).
private struct LoadFailed: View {
    var message: String?
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("플랜을 불러오지 못했어요")
                .wpTypography(16, .bold)
                .foregroundStyle(WPColor.fgNeutral)
            if let message, !message.isEmpty {
                Spacer().frame(height: 6)
                Text(message)
                    .wpTypography(13, lineHeight: 20)
                    .foregroundStyle(WPColor.fgSubtle)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 16)
            Button(action: onRetry) {
                Text("다시 시도")
                    .wpTypography(14, .bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("main.retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
    }
}

/// 웹: `w-full h-16 bg-[#ee2b8c] rounded-2xl font-bold text-lg shadow-xl shadow-[#ee2b8c44]`
private struct LoginButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("로그인 하기")
                .font(WPFont.hak(18, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    WPColor.primary,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: WPColor.primary.opacity(0.27), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 빈 자리 — 새싹

/// 홈 '이번 달에 할 일' 이 비었을 때 — `텅~` 대신 **새싹이 자라는 그림**으로 첫 플랜을 권한다
/// (안드로이드 `PlanSproutEmpty`, 2026-10-07 사용자 요청 — 웹은 아직 `텅~` 이라 **웹과 다르다**).
///
/// - 처음 그릴 때 줄기가 자라고 잎 두 장이 차례로 핀다(한 번). 그 뒤로 새싹이 살랑이고, 빈 카드의 `+` 가
///   떠오르고, 잎 빛 점이 올라가고, 버튼 뒤로 물결이 퍼진다(계속).
/// - 그림·버튼 어디를 눌러도 플랜 추가다. `onAdd` 가 없으면(읽기 전용) 버튼도 분홍 `+` 도 없다.
/// - 좌표는 시안(SVG)의 pt 그대로 — 무대 230×136 안에 빈 카드(210×64)를 아래에, 새싹을 그 위 가운데에 둔다.
/// - **데모 모드(UI 테스트)에서는 다 자란 모습으로 멈춘다** — XCUITest 는 앱이 쉴 때까지 기다리는데,
///   끝나지 않는 움직임이면 캡처가 시간 초과로 죽는다(`SkeletonBox` 와 같은 이유).
private struct PlanSproutEmpty: View {
    var title: String
    var onAdd: (() -> Void)?
    var lowScreen = false
    var compact = false

    @State private var start = Date()
    private static let frozen = ProcessInfo.processInfo.arguments.contains("-WPDemoMode")

    var body: some View {
        let scale: CGFloat = compact ? 0.72 : 1
        let tight = lowScreen || compact
        VStack(spacing: 0) {
            TimelineView(.animation(paused: Self.frozen)) { context in
                let t = Self.frozen ? 0 : context.date.timeIntervalSince(start)
                Canvas { ctx, _ in
                    ctx.scaleBy(x: scale, y: scale)
                    Self.drawStage(&ctx, clock: SproutClock(t: t, frozen: Self.frozen), showPlus: onAdd != nil)
                }
            }
            .frame(width: 230 * scale, height: 136 * scale)
            .contentShape(Rectangle())
            .onTapGesture { onAdd?() }
            .accessibilityHidden(true)

            Text(title.wpKeepAll)
                .wpTypography(17, .bold)
                .foregroundStyle(WPColor.fgNeutral)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .accessibilityLabel(title)

            if let onAdd {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        WPLucideIcon(paths: ["M5 12h14", "M12 5v14"], size: 16, color: .white, strokeWidth: 3)
                        Text("플랜 추가하기")
                            .wpTypography(14.5, .bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .frame(minHeight: 44)
                    .background(WPColor.primary, in: Capsule())
                    .background {
                        // 버튼 뒤로 퍼지는 물결 — 자리를 차지하지 않게 그림자처럼 바깥에 그린다
                        if !Self.frozen {
                            TimelineView(.animation) { context in
                                let p = Self.easeOut(context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: 2.2) / 2.2)
                                let fade = min(1, max(0, 1 - p / 0.7))
                                Capsule()
                                    .fill(WPColor.primary.opacity(0.32 * fade))
                                    .scaleEffect(x: 1 + 0.22 * p, y: 1 + 0.5 * p)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
                .accessibilityIdentifier("main.sproutAdd")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, tight ? 4 : 12)
        .padding(.bottom, tight ? 16 : 40)
    }

    /// 움직이는 값 — 안드로이드 `rememberInfiniteTransition` 의 네 박자와 한 번의 자람
    private struct SproutClock {
        var grow: CGFloat
        var sway: CGFloat
        var bob: CGFloat
        var sparks: CGFloat

        init(t: TimeInterval, frozen: Bool) {
            guard !frozen else {
                grow = 1; sway = 0; bob = 0.5; sparks = -1
                return
            }
            grow = CGFloat(min(1, t / 1.1))
            sway = -3 + 6 * Self.pingPong(t, period: 1.6)
            bob = Self.pingPong(t, period: 1.2)
            sparks = CGFloat((t / 3.2).truncatingRemainder(dividingBy: 1))
        }

        /// `tween(FastOutSlowIn)` + `RepeatMode.Reverse` — 0→1→0
        private static func pingPong(_ t: TimeInterval, period: Double) -> CGFloat {
            let phase = t / period
            let frac = phase.truncatingRemainder(dividingBy: 1)
            let eased = 0.5 - 0.5 * cos(Double.pi * frac)
            return CGFloat(Int(phase) % 2 == 0 ? eased : 1 - eased)
        }
    }

    private static func easeOut(_ x: Double) -> Double {
        let t = 1 - min(1, max(0, x))
        return 1 - t * t * t
    }

    /// easeOutBack — 잎이 살짝 넘쳤다가 자리를 잡는다
    private static func overshoot(_ x: CGFloat) -> CGFloat {
        let t = min(1, max(0, x)) - 1
        return 1 + 2.70158 * t * t * t + 1.70158 * t * t
    }

    private static func leafPath(mirror: Bool) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: mirror ? 64 - x : x, y: y) }
        var path = Path()
        path.move(to: p(32, 40))
        path.addCurve(to: p(10, 22), control1: p(22, 40), control2: p(10, 33))
        path.addCurve(to: p(21, 14), control1: p(10, 15), control2: p(16, 12))
        path.addCurve(to: p(32, 40), control1: p(27, 16), control2: p(32, 26))
        path.closeSubpath()
        return path
    }

    private static func drawStage(_ ctx: inout GraphicsContext, clock: SproutClock, showPlus: Bool) {
        let cardLeft: CGFloat = 10, cardTop: CGFloat = 72, cardW: CGFloat = 210, cardH: CGFloat = 64
        let centerX = cardLeft + cardW / 2

        // 잎 빛 점 — 3.2초마다 세 개가 차례로 올라가며 사라진다
        if clock.sparks >= 0 {
            for (x, delay, r) in [(centerX - 31, 0.41, 3.0), (centerX + 23, 0.66, 2.5), (centerX - 5, 0.91, 2.0)] as [(CGFloat, CGFloat, CGFloat)] {
                let t = (clock.sparks - delay + 1).truncatingRemainder(dividingBy: 1)
                if t > 0.6 { continue }
                let k = t / 0.6
                let alpha = k < 0.15 ? k / 0.15 * 0.9 : 0.9 * (1 - (k - 0.15) / 0.85)
                let radius = r * (0.6 + 0.4 * k)
                let center = CGPoint(x: x, y: 40 - 46 * k)
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(HomeColor.sproutLeafLight.opacity(alpha)))
            }
        }

        // 새싹 — 줄기가 자라고(0~0.55) 잎이 차례로 핀다(왼 0.45~0.85, 오른 0.6~1). 다 자란 뒤로 살랑인다
        var sprout = ctx
        sprout.translateBy(x: centerX - 32, y: cardTop + 6 - 76)
        let swayDeg = clock.sway * CGFloat(easeOut(Double((clock.grow - 0.85) / 0.15)))
        sprout.translateBy(x: 32, y: 76)
        sprout.rotate(by: .degrees(Double(swayDeg)))
        sprout.translateBy(x: -32, y: -76)

        let stem = CGFloat(easeOut(Double(clock.grow / 0.55)))
        if stem > 0 {
            var stemCtx = sprout
            stemCtx.translateBy(x: 32, y: 76)
            stemCtx.scaleBy(x: 1, y: stem)
            stemCtx.translateBy(x: -32, y: -76)
            var path = Path()
            path.move(to: CGPoint(x: 32, y: 76))
            path.addCurve(to: CGPoint(x: 32, y: 40), control1: CGPoint(x: 32, y: 64), control2: CGPoint(x: 31, y: 52))
            stemCtx.stroke(path, with: .color(HomeColor.sproutStem), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }
        let left = clock.grow > 0.45 ? overshoot((clock.grow - 0.45) / 0.4) : 0
        let right = clock.grow > 0.6 ? overshoot((clock.grow - 0.6) / 0.4) : 0
        for (amount, mirror, color) in [(left, false, WPColor.primary), (right, true, HomeColor.sproutLeafLight)] where amount > 0 {
            var leaf = sprout
            leaf.translateBy(x: 32, y: 40)
            leaf.scaleBy(x: amount, y: amount)
            leaf.translateBy(x: -32, y: -40)
            leaf.fill(leafPath(mirror: mirror), with: .color(color))
        }

        // 빈 카드 — 점선 테두리 · 동그라미 · 막대 둘(이번 달 할 일 카드의 자리)
        let card = Path(roundedRect: CGRect(x: cardLeft, y: cardTop, width: cardW, height: cardH), cornerRadius: 16)
        ctx.fill(card, with: .color(WPColor.fill))
        ctx.stroke(card, with: .color(HomeColor.ghostLine), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        ctx.stroke(Path(ellipseIn: CGRect(x: cardLeft + 23 - 9, y: cardTop + cardH / 2 - 9, width: 18, height: 18)),
                   with: .color(HomeColor.ghostMark), lineWidth: 1.5)
        let barLeft = cardLeft + 42, barW = cardW - 42 - 18
        ctx.fill(Path(roundedRect: CGRect(x: barLeft, y: cardTop + 21, width: barW, height: 8), cornerRadius: 4), with: .color(HomeColor.ghostBar))
        ctx.fill(Path(roundedRect: CGRect(x: barLeft, y: cardTop + 36, width: barW * 0.55, height: 8), cornerRadius: 4), with: .color(HomeColor.ghostBar))

        // `+` 단추 — 카드 오른쪽 위에 걸쳐 떠오른다. 누를 곳이 없으면(읽기 전용) 그리지 않는다
        guard showPlus else { return }
        let plus = CGPoint(x: cardLeft + cardW - 4, y: cardTop + 4 - 4 * clock.bob)
        ctx.fill(Path(ellipseIn: CGRect(x: plus.x - 13, y: plus.y - 13, width: 26, height: 26)), with: .color(WPColor.primary))
        var cross = Path()
        cross.move(to: CGPoint(x: plus.x - 5, y: plus.y)); cross.addLine(to: CGPoint(x: plus.x + 5, y: plus.y))
        cross.move(to: CGPoint(x: plus.x, y: plus.y - 5)); cross.addLine(to: CGPoint(x: plus.x, y: plus.y + 5))
        ctx.stroke(cross, with: .color(.white), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }
}
