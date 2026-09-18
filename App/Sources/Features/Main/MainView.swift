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
struct MainView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @StateObject private var model = MainViewModel()
    @State private var path = NavigationPath()
    @State private var showAddPlan = false

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
                LazyVStack(alignment: .leading, spacing: 0) {
                    head

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

                    listSection(buckets)

                    // 웹: 비로그인일 때만 목록 아래에 노출
                    if model.isGuest {
                        LoginButton { env.isAuthenticated = false }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                }
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
        .task {
            today = KstDate.today()
            await model.load(env: env, guest: guest)
        }
        .navigationDestination(for: Int.self) { scheduleId in
            ScheduleDetailView(scheduleId: scheduleId)
        }
        .navigationDestination(for: BudgetRoute.self) { route in
            BudgetDetailView(roomId: route.roomId.map(String.init))
        }
        .navigationDestination(for: CalendarRoute.self) { route in
            CalendarView(roomId: route.roomId, readOnly: route.readOnly)
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
        BrandHead {
            HStack(spacing: 8) {
                if model.planLoading {
                    SkeletonBox(width: 110, height: 22, onBrand: true)
                } else {
                    // 이름은 "누구의 플랜인지" 확인시키는 라벨이라 18pt 로 낮춘다(예전 30pt).
                    Text(model.displayName.isEmpty ? "이름" : model.displayName)
                        .font(WPFont.tmoney(18, .bold))
                        .tracking(-0.02 * 18)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HeadAvatars(initials: model.headerInitials)
                }
                Spacer(minLength: 0)
            }

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

            Spacer().frame(height: 16)

            if model.planLoading {
                // 아래 실제 요약 상자와 **같은 크기** — 받는 순간 목록이 튀지 않게.
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonBox(width: 160, height: 18, onBrand: true)
                    SkeletonBox(width: 208, height: 15, onBrand: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                // 면이 이미 분홍이라 여기서는 한 줄 요약 + 부연만 낸다.
                // 큰 숫자·막대는 예산 상세가 맡는다.
                HeadInset(action: { path.append(BudgetRoute(roomId: model.roomIdValue)) }) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("남은 예산 \(withThousands(model.remainingBudget))만 원")
                                .font(WPFont.hak(14, .bold))
                                .foregroundStyle(.white)
                            Text("\(withThousands(model.totalBudget))만 원 중 \(withThousands(model.usedBudget))만 원 지출·예정")
                                .font(WPFont.hak(12))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .accessibilityIdentifier("main.budget")
            }
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
