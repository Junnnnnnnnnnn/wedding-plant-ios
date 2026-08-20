import SwiftUI
import WPModels
import WPUtils

/// 웹 `SpendingAnalysis.tsx:SAVINGS_TOOLTIP` 원문.
///
/// - Note: 안드로이드는 이 문구를 자체적으로 다시 쓴 버전("위 카드의 '남은 금액'은 …")을 쓴다.
///   iOS 는 **웹 문구를 기준**으로 맞춘다. 세 앱을 통일하려면 웹/안드로이드 쪽을 먼저 정해야 한다.
private let savingsTooltip =
    "초기 자본에서 사용한 금액을 뺀 나머지예요. 플러스면 아직 쓸 수 있는 여유 예산, "
    + "마이너스면 사용액이 초기 자본을 초과한 상태예요."

/// 웹 `app/budget-detail/page.tsx` 이식.
///
/// 구성(웹 순서 그대로):
/// 뒤로가기·가이드 헤더 → 통계 카드 3장 → AI 버튼 → 지출 분석(사용률·잔액 배지·카테고리 막대)
/// → 예정/사용 탭 → 항목 리스트
struct BudgetDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: BudgetDetailViewModel
    @State private var showAiModal = false
    @State private var showSavingsTip = false

    init(roomId: String? = nil) {
        _model = StateObject(wrappedValue: BudgetDetailViewModel(roomId: roomId))
    }

    var body: some View {
        ZStack {
            WPScreenBackground()

            ScrollView {
                VStack(spacing: 0) {
                    header

                    if model.loading {
                        ProgressView()
                            .tint(WPColor.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 320)
                    } else if let message = model.errorMessage {
                        errorState(message)
                    } else if model.detail == nil {
                        Text("데이터가 없습니다.")
                            .font(WPFont.hak(16, .medium))
                            .foregroundStyle(WPColor.gray500)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 32)
                    } else {
                        StatGrid(model: model)

                        Spacer().frame(height: 8)
                        AiButton { showAiModal = true }

                        ZStack {
                            VStack(spacing: 0) {
                                Spacer().frame(height: 32)
                                AnalysisSection(
                                    model: model,
                                    showTip: showSavingsTip,
                                    onToggleTip: { showSavingsTip.toggle() }
                                )

                                Spacer().frame(height: 32)
                                TabsRow(model: model)

                                Spacer().frame(height: 16)
                                ExpenseList(items: model.items)
                            }
                            // 웹: 비로그인은 blur + pointer-events-none
                            .blur(radius: model.isGuest ? 6 : 0)
                            .allowsHitTesting(!model.isGuest)

                            if model.isGuest {
                                Button {
                                    env.isAuthenticated = false
                                } label: {
                                    Text("로그인이 필요한 서비스 입니다")
                                        .font(WPFont.hak(14, .bold))
                                        .foregroundStyle(WPColor.stone700)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            Color.white.opacity(0.7),
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 웹 `pb-32`
                    Spacer().frame(height: 128)
                }
            }
            .accessibilityIdentifier("budget.scroll")
        }
        .navigationBarBackButtonHidden()
        .task { await model.load(env: env, guest: guest) }
        // 오버레이로 띄우면 딤이 하단 탭바를 덮지 못한다. 웹은 `fixed inset-0` 로 전부 덮는다.
        .fullScreenCover(isPresented: $showAiModal) {
            AiPreparingModal { showAiModal = false }
                .presentationBackground(.clear)
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("뒤로가기")
                        .font(WPFont.hak(16, .bold))
                }
                .foregroundStyle(WPColor.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.3), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("budget.back")

            Spacer()

            // 가이드는 아직 이식 전이다. 자리와 모양만 웹과 맞춰 둔다.
            Image(systemName: "questionmark.circle")
                .font(.system(size: 24))
                .foregroundStyle(WPColor.stone400)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.3), in: Circle())
                .accessibilityLabel("가이드 보기")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(WPFont.hak(16, .semibold))
                .foregroundStyle(WPColor.primary)
                .multilineTextAlignment(.center)

            Button {
                Task { await model.load(env: env, guest: guest) }
            } label: {
                Text("다시 시도")
                    .font(WPFont.hak(14, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("budget.retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
    }
}

// MARK: - 통계 카드

/// 웹 `StatCard.tsx` 의 세 가지 variant.
private enum StatVariant { case white, pinkLight, pinkSolid }

private struct StatGrid: View {
    @ObservedObject var model: BudgetDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            StatCard(
                label: "초기 자본",
                value: model.initialCapital,
                variant: .white,
                large: true,
                // 초기 자본 카드에만 있는 우측 하단 문구
                remainingAmount: model.remaining
            )

            HStack(spacing: 12) {
                StatCard(label: "예정", value: model.plannedTotal, variant: .pinkLight)
                StatCard(label: "사용", value: model.usedTotal, variant: .pinkSolid)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

private struct StatCard: View {
    var label: String
    var value: Int
    var variant: StatVariant
    var large: Bool = false
    var remainingAmount: Int?

    var body: some View {
        let labelSize: CGFloat = large ? 12 : 10
        let valueSize: CGFloat = large ? 30 : 24

        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                // 웹 `tracking-[0.15em]`
                .font(WPFont.hak(labelSize, .black))
                .tracking(labelSize * 0.15)
                .foregroundStyle(labelColor)

            Text("\(wpThousands(value))만원")
                .font(WPFont.hak(valueSize, .black))
                .tracking(WPFont.trackingTight(valueSize))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let remainingAmount {
                Text("남은 금액 \(wpThousands(remainingAmount))만원")
                    .font(WPFont.hak(14, .semibold))
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
            }
        }
        .padding(large ? 24 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            if let border {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
        }
        .shadow(color: shadow, radius: variant == .pinkSolid ? 10 : 3, y: variant == .pinkSolid ? 4 : 1)
    }

    private var background: Color {
        switch variant {
        case .white: return .white
        // 웹 `bg-[#fff0f7]`
        case .pinkLight: return Color(hex: 0xFFF0F7)
        case .pinkSolid: return WPColor.primary
        }
    }

    private var border: Color? {
        switch variant {
        // 웹 `border-[#ee2b8c1a]`
        case .white: return WPColor.primary.opacity(Double(0x1A) / 255)
        // 웹 `border-[#ee2b8c11]`
        case .pinkLight: return WPColor.primary.opacity(Double(0x11) / 255)
        case .pinkSolid: return nil
        }
    }

    /// 웹 `shadow-[#ee2b8c33]` (= 알파 0x33)
    private var shadow: Color {
        switch variant {
        case .pinkSolid: return WPColor.primary.opacity(Double(0x33) / 255)
        case .white: return Color.black.opacity(0.04)
        case .pinkLight: return .clear
        }
    }

    private var valueColor: Color {
        switch variant {
        case .white: return WPColor.textPrimary
        case .pinkLight: return WPColor.primary
        case .pinkSolid: return .white
        }
    }

    /// 웹 `labelStyles` — `#ee2b8c88` / `#ee2b8cbb` / `white/80`
    private var labelColor: Color {
        switch variant {
        case .white: return WPColor.primary.opacity(Double(0x88) / 255)
        case .pinkLight: return WPColor.primary.opacity(Double(0xBB) / 255)
        case .pinkSolid: return Color.white.opacity(0.8)
        }
    }
}

// MARK: - AI 버튼

private struct AiButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                Text("AI에게 예산 조언 받기")
                    .font(WPFont.hak(16, .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                // 웹 `from-purple-500 to-[#ee2b8c]`
                LinearGradient(
                    colors: [Color(hex: 0xA855F7), WPColor.primary],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            // 웹 `shadow-[#ee2b8c22]`
            .shadow(color: WPColor.primary.opacity(Double(0x22) / 255), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("budget.ai")
    }
}

// MARK: - 지출 분석

private struct AnalysisSection: View {
    @ObservedObject var model: BudgetDetailViewModel
    var showTip: Bool
    var onToggleTip: () -> Void

    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("지출 분석")
                    .font(WPFont.hak(20, .bold))
                    .foregroundStyle(WPColor.textPrimary)

                Spacer()

                if model.selectedCategory != nil {
                    Button {
                        Task { await model.clearCategory(env: env, guest: guest) }
                    } label: {
                        Text("필터 해제")
                            .font(WPFont.hak(10, .black))
                            // 웹 `tracking-widest` (= 0.1em)
                            .tracking(1)
                            .foregroundStyle(WPColor.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(WPColor.primary.opacity(Double(0x11) / 255), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("budget.clearFilter")
                }
            }

            Spacer().frame(height: 16)

            card
        }
        .padding(.horizontal, 16)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("전체 사용률")
                        .font(WPFont.hak(10, .black))
                        .tracking(1)
                        .foregroundStyle(WPColor.primary.opacity(Double(0x88) / 255))

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // verbatim 필수 — 숫자 자동 포맷(천 단위 구분) 방지
                        Text(verbatim: "\(model.usedPercent)%")
                            .font(WPFont.hak(36, .black))
                            // 웹 `tracking-tighter` (= -0.05em)
                            .tracking(-0.05 * 36)
                            .foregroundStyle(WPColor.textPrimary)
                        Text("사용")
                            .font(WPFont.hak(14, .bold))
                            .foregroundStyle(WPColor.gray400)
                    }
                }

                Spacer(minLength: 8)

                SavingsBadge(savings: model.savings, onTapHelp: onToggleTip)
            }

            // 웹은 이 말풍선을 배지 아래에 떠 있게(absolute) 두지만, 오버레이로 띄우면
            // 높이를 배지 기준으로 제안받아 글자가 잘린다. 흐름 안에 두어 전문이 보이게 한다.
            if showTip {
                SavingsTooltip()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 8)
            }

            Spacer().frame(height: 32)

            if model.sortedCategories.isEmpty {
                Text("카테고리 데이터가 없습니다.")
                    .font(WPFont.hak(14, .medium))
                    .italic()
                    .foregroundStyle(WPColor.gray400)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 24) {
                    ForEach(model.sortedCategories) { item in
                        CategoryBar(
                            item: item,
                            active: model.selectedCategory == item.categoryName,
                            dimmed: model.selectedCategory != nil
                                && model.selectedCategory != item.categoryName
                        ) {
                            Task { await model.toggleCategory(item.categoryName, env: env, guest: guest) }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(WPColor.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
    }
}

/// 웹의 초록/빨강 잔액 배지. 숫자만 보여주고, 물음표를 눌러야 설명이 뜬다.
private struct SavingsBadge: View {
    var savings: Int
    var onTapHelp: () -> Void

    var body: some View {
        let positive = savings >= 0
        // 웹 green-50 / green-600, red-50 / red-600
        let background = positive ? Color(hex: 0xF0FDF4) : Color(hex: 0xFEF2F2)
        let foreground = positive ? Color(hex: 0x16A34A) : Color(hex: 0xDC2626)

        HStack(spacing: 4) {
            Text(verbatim: (positive ? "+" : "-") + wpThousands(abs(savings)))
                .font(WPFont.hak(12, .black))
                .tracking(WPFont.trackingTight(12))
                .foregroundStyle(foreground)

            Button(action: onTapHelp) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(foreground)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("이 숫자의 의미 보기")
            .accessibilityIdentifier("budget.savings.help")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SavingsTooltip: View {
    var body: some View {
        Text(savingsTooltip)
            .font(WPFont.hak(12))
            .lineSpacing(6)
            .foregroundStyle(.white)
            .frame(width: 256, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .background(WPColor.textPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 12, y: 6)
    }
}

private struct CategoryBar: View {
    var item: CategoryChartItem
    var active: Bool
    var dimmed: Bool
    var onTap: () -> Void

    /// 웹 `opacity-30 grayscale` 을 **계산해서 얻은 최종 색**.
    ///
    /// SwiftUI 의 `.grayscale()` + `.opacity()` 를 버튼에 걸어 봤지만 막대만 그대로 진하게
    /// 남는다(글자에는 먹는다). 필터에 기대지 말고 색을 직접 지정한다.
    /// `#ee2b8c` → 회색조 `#5b5b5b` → 흰 배경 위 30% ≈ `#cfcfcf`.
    private static let dimmedGray = Color(hex: 0xCFCFCF)

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    // 카테고리 이름은 사용자 입력값이므로 Tmoney
                    Text(item.categoryName)
                        .font(WPFont.tmoney(11, .black))
                        .tracking(WPFont.trackingTight(11))
                        .foregroundStyle(nameColor)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    HStack(spacing: 2) {
                        Text(verbatim: "\(wpThousands(item.used)) / \(wpThousands(item.total))")
                            .font(WPFont.hak(11, .bold))
                            .foregroundStyle(dimmed ? Self.dimmedGray : WPColor.primary)
                        // 웹: 단위만 더 작고 회색
                        Text("만원")
                            .font(WPFont.hak(10, .semibold))
                            .foregroundStyle(dimmed ? Self.dimmedGray : WPColor.gray500)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // 웹 `bg-[#ee2b8c0a]`
                        Capsule().fill(WPColor.primary.opacity(Double(0x0A) / 255))
                        Capsule()
                            .fill(dimmed ? Self.dimmedGray : WPColor.primary)
                            .frame(width: geo.size.width * item.ratio)
                    }
                }
                .frame(height: 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 웹 `scale-[0.98]` / 선택된 항목은 `translate-x-1`
        .scaleEffect(dimmed ? 0.98 : 1)
        .offset(x: active ? 4 : 0)
        .animation(.easeOut(duration: 0.3), value: dimmed)
        .animation(.easeOut(duration: 0.3), value: active)
    }

    private var nameColor: Color {
        if dimmed { return Self.dimmedGray }
        return active ? WPColor.primary : WPColor.textPrimary.opacity(0.7)
    }
}

// MARK: - 탭 + 목록

private struct TabsRow: View {
    @ObservedObject var model: BudgetDetailViewModel

    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BudgetDetailViewModel.Tab.allCases) { tab in
                let active = model.tab == tab
                Button {
                    Task { await model.setTab(tab, env: env, guest: guest) }
                } label: {
                    Text(tab.label)
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(active ? WPColor.primary : WPColor.gray400)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                        // 활성 탭만 2px 밑줄 (웹 `border-b-2`)
                        .overlay(alignment: .bottom) {
                            if active {
                                Rectangle().fill(WPColor.primary).frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("budget.tab.\(tab.rawValue)")
            }
        }
        // 탭 줄 전체를 받치는 1px 선 (웹 `border-b border-gray-100`)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WPColor.gray100).frame(height: 1)
        }
        .padding(.horizontal, 16)
    }
}

private struct ExpenseList: View {
    var items: [ScheduleItem]

    var body: some View {
        VStack(spacing: 16) {
            if items.isEmpty {
                Text("이 카테고리에 항목이 없습니다.")
                    .font(WPFont.hak(16, .medium))
                    .italic()
                    .foregroundStyle(WPColor.gray400)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
            } else {
                ForEach(items) { item in
                    ExpenseRow(item: item)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct ExpenseRow: View {
    var item: ScheduleItem

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: Self.icon(for: item.categoryName))
                .font(.system(size: 20))
                .foregroundStyle(WPColor.primary)
                .frame(width: 56, height: 56)
                .background(
                    WPColor.primary.opacity(Double(0x0A) / 255),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 0) {
                // 제목·카테고리 모두 사용자 입력값이라 Tmoney
                Text(item.title)
                    .font(WPFont.tmoney(18, .bold))
                    .foregroundStyle(WPColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(item.categoryName)
                    .font(WPFont.tmoney(12, .semibold))
                    .tracking(WPFont.trackingTight(12))
                    .foregroundStyle(WPColor.gray400)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                // 웹은 여기서만 "만 원" 으로 띄어 쓴다 (통계 카드는 "만원")
                Text("\(wpThousands(item.amount ?? 0))만 원")
                    .font(WPFont.hak(18, .black))
                    .foregroundStyle(WPColor.textPrimary)

                StatusBadge(paid: paid)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WPColor.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
        // 웹: 예정 항목은 살짝 흐리다
        .opacity(paid ? 1 : 0.9)
    }

    private var paid: Bool { item.status?.isCompleted ?? false }

    /// 웹 `constants.tsx:CATEGORY_ICONS`. 등록되지 않은 이름은 모두 `Others` 로 떨어진다.
    ///
    /// 실제 서비스의 카테고리(웨딩홀·드레스 …)는 표에 없어서 사실상 전부 말줄임 아이콘이 나온다.
    /// 웹과 다르게 보이면 안 되므로 표를 그대로 옮겨 둔다.
    private static func icon(for category: String) -> String {
        switch category {
        case "Dinner Venue", "저녁 식사": return "fork.knife"
        case "Wedding Ring", "결혼반지": return "diamond"
        case "Photography": return "camera"
        case "Parent's Gift", "혼주 구매": return "gift"
        case "Flowers": return "leaf"
        case "Attire": return "tshirt"
        default: return "ellipsis"
        }
    }
}

/// 웹 `ExpenseList.tsx:StatusBadge`. 백엔드 상태는 완료/그 외 두 가지만 온다.
private struct StatusBadge: View {
    var paid: Bool

    var body: some View {
        Text(paid ? "결제완료" : "예정")
            .font(WPFont.hak(10, .black))
            .tracking(WPFont.trackingTight(10))
            .foregroundStyle(paid ? Color.white : WPColor.gray500)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(
                paid ? WPColor.primary : WPColor.gray100,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}

// MARK: - AI 준비중 안내

/// 웹 `budget-detail` 의 `AIInsightsModal`.
///
/// 문구는 웹 상수(`AI_PREP_TITLE` / `AI_PREP_SUBTITLE`)를 **글자 그대로** 옮긴 것이다.
/// 이모지도 웹 원문 그대로.
private struct AiPreparingModal: View {
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                Text("AI 서비스 준비중이예요!")
                    .font(WPFont.hak(18, .semibold))
                    .foregroundStyle(WPColor.stone900)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 12)

                Text("조금만 기다려 주세요 \u{1F647}\u{200D}\u{2642}\u{FE0F}")
                    .font(WPFont.hak(15))
                    .lineSpacing(6)
                    .foregroundStyle(WPColor.stone700)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 24)

                Button(action: onClose) {
                    Text("닫기")
                        .font(WPFont.hak(14, .semibold))
                        .foregroundStyle(WPColor.stone700)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().stroke(WPColor.stone300, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("budget.ai.close")
            }
            .padding(24)
            .frame(maxWidth: 384)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
        }
    }
}
