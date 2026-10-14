import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/main/page.tsx` 의 **폰 트리(`md:hidden`)** 이식 — 시안 C안 01.
/// 안드로이드 `ui/main/MainScreen.kt` 와 같은 화면이다.
///
/// ```
/// [분홍 머리 면]  이름 · 이니셜 아바타
///                 결혼식까지 / N일 남았어요        ← 32pt, 이 화면에서 사람이 보는 값
///                 2026년 11월 14일 (토) · 예식장
///                 [남은 예산 N만 원 / M만 원 중 K만 원 지출·예정  >]
/// 이번 달에 할 일 N                               추가
///   회색 채움 카드 (체크 · 제목 · 태그 · 날짜 · 금액)
/// 그 다음  계획 중 N · 완료 M                      전체
///   구분선 목록
/// ```
///
/// **걷어낸 것**: "플랜 리스트" 제목, 카테고리 칩, 정렬 버튼, 계획 중/완료 탭,
/// 56pt 아이콘 타일, 예정/임박 배지, 떠 있는 예산 카드. 카테고리로 좁혀 보기와
/// 완료 되짚기는 `전체`(캘린더)가 맡는다.
///
/// **아직 안 옮긴 것** — 각각 iOS 에 없는 부품에 묶여 있다.
/// 가이드 오버레이(머리 면의 `?`), 초대 띠(`SoloPlanBanner`), 자랑하기 토글.
/// 눌러도 아무 일이 없는 버튼을 미리 두지 않는다.
/// 웹 `MOBILE_GUIDE_STEPS` 와 **문구·순서가 같아야 한다.**
///
/// **앵커를 지우거나 이름을 바꾸지 말 것.** 대상을 못 찾으면 스팟라이트가 0×0 으로
/// 붕괴해 화면만 까맣게 덮인다(웹에서 실제로 그랬다).
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
    @StateObject private var model = MainViewModel()
    @StateObject private var invitation = InvitationStore()
    @State private var path = NavigationPath()
    @State private var showAddPlan = false
    /// `/plan/brag/my` 를 홈이 다시 그릴 때마다 또 부르지 않도록 하나로 들고 있는다.
    @StateObject private var bragToggle = BragToggleViewModel()
    @State private var showInvite = false
    @State private var showPass = false
    @EnvironmentObject private var guide: GuideController

    /// 묶음 기준일. 렌더마다 새로 만들면 묶음이 흔들린다(웹 `todayForBuckets`).
    @State private var today = KstDate.today()

    var body: some View {
        NavigationStack(path: $path) {
            content
        }
    }

    private var content: some View {
        let buckets = model.timeBuckets(today: today)

        return VStack(spacing: 0) {
            ScrollView {
                // 높이가 비동기로 바뀌는 정원·결제 카드와 가이드 좌표를 함께 배치한다.
                // LazyVStack은 작은 화면의 스크롤 중 배치 계산이 반복될 수 있어 전체 높이를 확정한다.
                VStack(alignment: .leading, spacing: 0) {
                    head
                    if (invitation.homeState == .empty || invitation.homeState == .mine), env.isMyAdRoom(model.roomIdValue) {
                        HomeInvitationEntry(model: invitation).padding(.horizontal, 16).padding(.top, 16)
                    }
                    if !model.planLoading && model.errorMessage == nil && !model.isGuest {
                        PayThisWeekView(schedules: model.planned + model.completed, today: today,
                            roomId: model.roomIdValue,
                            showReminder: !model.isRoomView || ["OWNER", "SPOUSE"].contains(model.myPermission?.rawValue.uppercased() ?? ""),
                            onSelect: { path.append($0) })
                    }


                    SectionHeader(
                        title: "이번 달에 할 일",
                        meta: model.planLoading ? nil : "\(buckets.thisMonth.count)",
                        // READ 권한이면 추가를 감춘다 —
                        // **눌러야만 실패를 아는 버튼은 두지 않는다.**
                        actionLabel: model.canWrite ? "추가" : nil,
                        onAction: { showAddPlan = true }
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

                    // 목록 아래 흰 면. 분홍 머리 면에 넣으면 얇은 예산 줄과 겹쳐
                    // 무엇을 누르는지 알기 어렵다.
                    if model.canBrag {
                        BragToggle(model: bragToggle) { path.append(BragRoute()) }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                }
                .id(model.planLoading)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("main.scroll")

            if let message = model.errorMessage {
                InfoBanner(message: message, actionLabel: "닫기") {
                    model.errorMessage = nil
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        // 분홍 머리 면이 상태바 뒤까지 깔리도록 스크롤 영역을 위로 넓힌다.
        // 면은 스크롤 영역 **안**에 있어 내용과 함께 올라간다(웹 `data-mobile-head`).
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        // **전환하는 동안 가림막으로 덮는다.** 안 덮으면 방을 묻는 사이에 화면이
        // 이미 내 개인 플랜을 그려서, 개인 플랜이 떴다가 방 플랜으로 바뀌는 게
        // 그대로 보인다.
        //
        // **공용 로딩 상태를 쓰지 않는다** — 누구나 끌 수 있어서 "스켈레톤을
        // 보여 주려고 끄는" 한 줄에 가림막까지 꺼지고, 그 틈으로 개인 예산이
        // 그대로 보였다. 그리고 **불투명이어야 한다**. 반투명이면 떠 있어도 큰
        // 숫자가 비친다.
        .overlay {
            if env.boundRoom.needsCover {
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

    // MARK: - 머리 면

    private var head: some View {
        BrandHead(bottom: 0, overhang: 72, passMember: invitation.result?.hasPass == true && env.isMyAdRoom(model.roomIdValue)) {
            HStack(spacing: 8) {
                if model.planLoading {
                    SkeletonBox(width: 110, height: 22, onBrand: true)
                } else {
                    NavigationLink { UserView() } label: {
                        HStack(spacing: 8) {
                            Text(model.displayName.isEmpty ? "이름" : model.displayName).font(WPFont.tmoney(18, .bold)).tracking(-0.36).lineLimit(1)
                            HeadAvatars(initials: model.headerInitials)
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium))
                        }.foregroundStyle(.white).frame(minHeight: 44)
                    }.accessibilityLabel("내 정보").accessibilityIdentifier("main.profile")
                }
                Spacer(minLength: 0)
                if invitation.result?.hasPass == true && env.isMyAdRoom(model.roomIdValue) {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf").font(.system(size: 13))
                        Text("준비 패스").font(WPFont.hak(9, .bold))
                        Image(systemName: "checkmark").font(.system(size: 10))
                    }.foregroundStyle(Color(hex: 0x875022)).padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color(hex: 0xFFF1B8), in: Capsule())
                }
            }
            .guideAnchor("main-header-info")

            if model.planLoading {
                Spacer().frame(height: 16)
                SkeletonBox(width: 240, height: 74, onBrand: true)
                Spacer().frame(height: 8)
                SkeletonBox(width: 190, height: 16, onBrand: true)
            } else {
                let sentence = model.dDaySentence
                Spacer().frame(height: 16)
                Text("\(sentence.0)\n\(sentence.1)")
                    .font(WPFont.hak(32, .bold))
                    .tracking(-0.045 * 32)
                    .lineSpacing(37 - 32)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 8)
                Text(subtitleText)
                    .font(WPFont.hak(14))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            // 온보딩에서 초대를 건너뛴 자리 — 배우자가 들어오면 사라진다.
            if model.showSoloBanner && !model.planLoading {
                Spacer().frame(height: 16)
                SoloPlanBanner { showInvite = true }
            }

            Spacer().frame(height: 16)

            VStack(spacing: 0) {
                Button { path.append(BudgetRoute(roomId: model.roomIdValue)) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if !model.amountsLoaded {
                                SkeletonBox(width: 64, height: 18); SkeletonBox(width: 144, height: 32)
                                SkeletonBox(width: 208, height: 18).padding(.top, 4)
                            } else {
                                Text(model.remainingBudget < 0 ? "예산 초과" : "남은 예산").font(WPFont.hak(13, .bold)).foregroundStyle(Color(hex: 0x847880))
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(withThousands(abs(model.remainingBudget))).font(WPFont.tmoney(32, .bold)).tracking(-1.44)
                                    Text("만 원").font(WPFont.tmoney(15, .bold))
                                }.foregroundStyle(model.remainingBudget < 0 ? Color.red : WPColor.textPrimary)
                                Text("\(withThousands(model.totalBudget))만 원 중 \(withThousands(model.usedBudget))만 원 지출·예정").font(WPFont.hak(12.5)).foregroundStyle(Color(hex: 0x847880)).padding(.top, 4)
                            }
                        }
                        Spacer()
                        if model.amountsLoaded { Image(systemName: "chevron.right").font(.system(size: 20)).foregroundStyle(WPColor.gray400) }
                    }.padding(.horizontal, 20).padding(.vertical, 16).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!model.amountsLoaded).accessibilityIdentifier("main.budget")
                HomeInvitationEntry(model: invitation, rowOnly: true)
            }.background(.white, in: RoundedRectangle(cornerRadius: 20)).clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color(hex: 0x1B0D14).opacity(0.08), radius: 10, y: 6)

        }
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
    private func listSection(
        _ buckets: (thisMonth: [ScheduleItem], later: [ScheduleItem])
    ) -> some View {
        if model.planLoading {
            // 받기 전에 "없다" 고 말하지 않는다 — 빈 상태 대신 뼈대를 낸다.
            ForEach(0..<5, id: \.self) { _ in SkeletonCard() }
        } else if model.isCompletelyEmpty {
            // 웹: 전체 플랜이 0개일 때만 "텅~"
            Text("텅~")
                .font(WPFont.hak(36, .semibold))
                .foregroundStyle(WPColor.stone400)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 64)
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
                Text(buckets.later.isEmpty ? "할 일을 추가해 볼까요?" : "이번 달은 비어 있어요")
                    .font(WPFont.hak(15))
                    .foregroundStyle(WPColor.fgSubtle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
            }

            // 앞으로 할 일은 구분선 목록으로 낮춘다 — 지금 당장이 아니라 카드만큼의
            // 무게가 필요 없고, 같은 화면에 훨씬 많이 들어온다.
            if AdRules.homeAdVisible(gate: env.adGate, isMyPlan: env.isMyAdRoom(model.roomIdValue) && !model.isGuest,
                                      thisMonthCount: buckets.thisMonth.count, hasMoreBelow: !buckets.later.isEmpty), model.errorMessage == nil {
                NativeAdSlot(placement: "home", style: .home)
            }
            if !buckets.later.isEmpty {
                SectionHeader(
                    title: "그 다음",
                    meta: laterMeta(buckets.later.count),
                    actionLabel: "전체",
                    onAction: {
                        path.append(
                            CalendarRoute(roomId: model.roomIdValue, readOnly: model.readOnly)
                        )
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 4)

                ForEach(buckets.later) { item in
                    LaterRow(item: item) { path.append(item.id) }
                }
            }
        }
    }

    private func laterMeta(_ count: Int) -> String {
        var text = "계획 중 \(count)"
        if model.completedTotal > 0 { text += " · 완료 \(model.completedTotal)" }
        return text
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

/// 자랑하기 목록. **레일에만 있고 하단 탭바에는 없다** — 탭 6개는 폰에서 좁고,
/// 자랑하기는 홈에서 들어가는 곳이다. 폰에는 레일이 없으므로 홈의 토글 아래
/// `보러 가기` 줄이 유일한 문이다.
struct BragRoute: Hashable {}

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
                Text(item.title)
                    .font(WPFont.tmoney(16, .bold))
                    .tracking(-0.01 * 16)
                    .foregroundStyle(checked ? WPColor.fgSubtle : WPColor.fgNeutral)
                    .strikethrough(checked)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !item.categoryName.isEmpty {
                        CategoryTag(name: item.categoryName, done: checked)
                    }
                    Text(dateLabel)
                        .font(WPFont.hak(13))
                        .foregroundStyle(WPColor.fgMuted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AmountText(amount: Double(item.amount ?? 0))
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
    }
}

/// 웹 `flex items-center border-b border-[#0000000c] px-1 py-3.5`
private struct LaterRow: View {
    var item: ScheduleItem
    var onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(WPFont.hak(14))
                        .foregroundStyle(WPColor.fgNeutral)
                        .lineLimit(1)
                    Text(item.categoryName)
                        .font(WPFont.hak(12))
                        .foregroundStyle(WPColor.fgSubtle)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(KstDate(dateString: item.startDate ?? "")?.monthDayText ?? "날짜 미정")
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.fgSubtle)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Hairline()
        }
        .padding(.horizontal, 16)
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
