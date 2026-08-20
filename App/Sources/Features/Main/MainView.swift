import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/main/page.tsx` 이식.
///
/// 구성(웹 순서 그대로):
/// 이름·초대 → 결혼식 날짜·D-Day → 예산 카드 → 플랜 리스트 헤더(정렬·추가) → 탭 → 리스트 → 로그인 버튼
struct MainView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @StateObject private var model = MainViewModel()
    @State private var showSortSheet = false
    @State private var showAddPlan = false

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        ZStack {
            WPScreenBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        Header(model: model)

                        Spacer().frame(height: 16)
                        BudgetCard(model: model)

                        Spacer().frame(height: 24)
                        PlanListHeader(model: model) {
                            showSortSheet = true
                        } onAddTapped: {
                            showAddPlan = true
                        }

                        Spacer().frame(height: 8)
                        Tabs(model: model)

                        listSection

                        // 웹: 비로그인일 때만 리스트 아래에 노출
                        if model.isGuest {
                            Spacer().frame(height: 16)
                            LoginButton {
                                env.isAuthenticated = false
                            }
                        }
                    }
                    .padding(16)
                }
                .accessibilityIdentifier("main.scroll")

                if let message = model.errorMessage {
                    InfoBanner(message: message, actionLabel: "닫기") {
                        model.errorMessage = nil
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .task {
            await model.load(env: env, guest: guest)
        }
        .navigationDestination(for: Int.self) { scheduleId in
            ScheduleDetailView(scheduleId: scheduleId)
        }
        .fullScreenCover(isPresented: $showAddPlan) {
            AddPlanView(roomId: model.roomIdValue) {
                Task { await model.load(env: env, guest: guest) }
            }
            .environmentObject(env)
            .environmentObject(guest)
        }
        .sheet(isPresented: $showSortSheet) {
            PlanSortSheet(selected: model.sort) { option in
                Task { await model.setSort(option, env: env, guest: guest) }
            }
        }
    }

    @ViewBuilder
    private var listSection: some View {
        if model.loading {
            ProgressView()
                .tint(WPColor.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
        } else if model.isCompletelyEmpty {
            EmptyMessage(text: "텅~", size: 36)
        } else if model.visibleList.isEmpty {
            EmptyMessage(
                // 이모지는 웹 원문 그대로다.
                text: model.tab == .completed ? "완료한 플랜이 없어요" : "모든 플랜을 완료했어요! 🎉",
                size: 20
            )
        } else {
            VStack(spacing: 12) {
                ForEach(model.visibleList) { item in
                    // 카드를 누르면 상세로. 체크박스는 카드 안에서 따로 처리한다.
                    NavigationLink(value: item.id) {
                        PlanRow(
                            item: item,
                            toggling: model.togglingIds.contains(item.id)
                        ) {
                            Task { await model.toggle(item, env: env) }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - 헤더

private struct Header: View {
    @ObservedObject var model: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(model.name.isEmpty ? "이름" : model.name)
                    // 웹: font-user-content text-3xl font-semibold text-[#1b0d14]
                    .font(WPFont.tmoney(30, .semibold))
                    .foregroundStyle(WPColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer().frame(width: 8)

                if model.members.isEmpty {
                    InviteButton()
                } else {
                    // OWNER 를 맨 앞으로, 최대 2명 (웹과 동일)
                    let ordered = model.members.sorted { lhs, _ in lhs.permission == .owner }
                    HStack(spacing: -8) {
                        ForEach(Array(ordered.prefix(2).enumerated()), id: \.element.id) { index, member in
                            MemberAvatar(name: member.name, index: index, size: 40)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "questionmark.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(WPColor.stone400)
                    .frame(width: 48, height: 48)
                    .accessibilityLabel("가이드 보기")
            }

            HStack(spacing: 8) {
                if let date = model.weddingDate {
                    Text("결혼식: \(date.weddingDateText)")
                        .font(WPFont.hak(12))
                        .foregroundStyle(WPColor.gray500)
                }
                DDayBadge(label: model.dDayLabel)
                    .accessibilityIdentifier("main.dday")
                Spacer(minLength: 0)
            }
        }
    }
}

/// 웹: `h-10 rounded-full px-4 bg-stone-100 border border-stone-200 text-sm font-semibold` + Mail 아이콘
private struct InviteButton: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "envelope")
                .font(.system(size: 14))
                .foregroundStyle(WPColor.stone600)
            Text("초대")
                .font(WPFont.hak(14, .semibold))
                .foregroundStyle(WPColor.textPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(WPColor.stone100, in: Capsule())
        .overlay(Capsule().stroke(WPColor.stone200, lineWidth: 1))
    }
}

// MARK: - 예산 카드

private struct BudgetCard: View {
    @ObservedObject var model: MainViewModel

    var body: some View {
        // 웹: 남은 금액이 1000 이상이면 32px, 미만이면 42px
        let amountSize: CGFloat = abs(model.remainingBudget) >= 1000 ? 32 : 42

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "wonsign")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.3), in: Circle())

                VStack(alignment: .leading, spacing: 12) {
                    Text("남은 예산")
                        .font(WPFont.hak(14, .semibold))
                        .foregroundStyle(.white)
                    Text("\(wpThousands(model.remainingBudget))만 원")
                        .font(WPFont.hak(amountSize, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }

            Spacer().frame(height: 12)

            Text("\(wpThousands(model.usedBudget))만 원 지출/예정")
                .font(WPFont.hak(20, .semibold))
                .foregroundStyle(.white)
                .padding(.leading, 52)

            Spacer().frame(height: 16)

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.3))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(model.usagePercentClamped) / 100)
                    }
                }
                .frame(height: 8)

                // verbatim 필수 — 숫자 자동 포맷(천 단위 구분) 방지
                Text(verbatim: "\(model.usagePercent)%")
                    .font(WPFont.hak(14))
                    .foregroundStyle(.white)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [WPColor.budgetGradientStart, WPColor.budgetGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .accessibilityIdentifier("main.budget")
    }
}

// MARK: - 플랜 리스트 헤더

private struct PlanListHeader: View {
    @ObservedObject var model: MainViewModel
    var onSortTapped: () -> Void
    var onAddTapped: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("플랜 리스트")
                        .font(WPFont.hak(20, .bold))
                        .foregroundStyle(WPColor.textPrimary)
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundStyle(WPColor.gray400)
                }
                if model.isCompletelyEmpty {
                    Text("플랜을 추가해볼까요?")
                        .font(WPFont.hak(14, .medium))
                        .foregroundStyle(WPColor.gray400)
                }
            }

            Spacer(minLength: 0)

            Button(action: onSortTapped) {
                SmallOutlineButton(
                    label: model.sort.buttonLabel,
                    symbol: model.sort.descending ? "arrow.down" : "arrow.up"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("main.sort")

            Button(action: onAddTapped) {
                SmallFilledButton(label: "추가", symbol: "plus.circle")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("main.add")
        }
    }
}

private struct SmallOutlineButton: View {
    var label: String
    var symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(WPFont.hak(12, .bold))
                .foregroundStyle(WPColor.stone600)
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(WPColor.stone600)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(WPColor.stone200, lineWidth: 2)
        )
    }
}

private struct SmallFilledButton: View {
    var label: String
    var symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(WPFont.hak(12, .bold))
                .foregroundStyle(.white)
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - 탭

/// 웹: `bg-gray-100/50 p-1.5 rounded-2xl border border-gray-100` 안의 세그먼트 2개
private struct Tabs: View {
    @ObservedObject var model: MainViewModel

    var body: some View {
        HStack(spacing: 0) {
            TabSegment(
                label: "계획 중",
                count: model.plannedTotal,
                selected: model.tab == .planned
            ) { model.tab = .planned }

            TabSegment(
                label: "완료",
                count: model.completedTotal,
                selected: model.tab == .completed
            ) { model.tab = .completed }
        }
        .padding(6)
        .background(
            WPColor.gray100.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WPColor.gray100, lineWidth: 1)
        )
    }
}

private struct TabSegment: View {
    var label: String
    var count: Int
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(WPFont.hak(14, .black))
                    .foregroundStyle(selected ? WPColor.primary : WPColor.gray400)
                Text(verbatim: "\(count)")
                    .font(WPFont.hak(10))
                    .foregroundStyle(selected ? WPColor.primary : WPColor.gray500)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        selected ? WPColor.primary.opacity(0.06) : WPColor.gray200,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 리스트

private struct EmptyMessage: View {
    var text: String
    var size: CGFloat

    var body: some View {
        Text(text)
            .font(WPFont.hak(size, .semibold))
            .foregroundStyle(WPColor.stone400)
            .frame(maxWidth: .infinity)
            .frame(height: 220)
    }
}

private struct PlanRow: View {
    var item: ScheduleItem
    var toggling: Bool
    var onToggle: () -> Void

    var body: some View {
        let checked = item.status?.isCompleted ?? false
        let status = PlanRules.dateStatus(startDate: item.startDate)
        let style = statusStyle(status)
        let dateLabel = item.startDate.flatMap { KstDate(dateString: $0) }?.listDateText ?? "미정"
        let amount = item.amount ?? 0

        HStack(spacing: 0) {
            // 카테고리 색 타일 + 체크박스
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(checked ? WPColor.primary : Color.white.opacity(0.8))
                        .overlay(Circle().stroke(WPColor.primary, lineWidth: 2))
                        .frame(width: 24, height: 24)
                    if checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 56, height: 56)
                .background(
                    Color(hex: PlanRules.categoryColorHex(item.categoryName)),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(toggling)

            Spacer().frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(WPFont.tmoney(18, .bold))
                    .foregroundStyle(checked ? WPColor.gray400 : WPColor.textPrimary)
                    .strikethrough(checked)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer().frame(height: 2)

                Text(item.categoryName)
                    .font(WPFont.tmoney(12, .semibold))
                    .foregroundStyle(WPColor.gray400)
                    .lineLimit(1)

                Text(dateLabel)
                    .font(WPFont.tmoney(12, .semibold))
                    .foregroundStyle(WPColor.gray400)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(amount > 0 ? "\(wpThousands(amount))만 원" : "미정")
                    .font(WPFont.hak(18, .heavy))
                    .foregroundStyle(WPColor.textPrimary)
                    .lineLimit(1)

                Text(status.label)
                    .font(WPFont.hak(10, .black))
                    .foregroundStyle(style.foreground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(style.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WPColor.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private func statusStyle(_ status: PlanRules.DateStatus) -> PlanStatusStyle {
        switch status {
        case .past: return .past
        case .today: return .today
        case .soon: return .soon
        case .upcoming: return .upcoming
        }
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
                .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: WPColor.primary.opacity(0.27), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("main.login")
    }
}
