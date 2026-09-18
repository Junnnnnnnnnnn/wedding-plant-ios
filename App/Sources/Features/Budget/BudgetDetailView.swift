import SwiftUI
import WPModels
import WPUtils

/// 웹 `app/budget-detail/page.tsx` 이식.
///
/// 구성: 뒤로가기·가이드 헤더 → **예산 도넛** → 지출 분석(카테고리)
/// → 예정/사용 탭 → 항목 목록
///
/// ## 도넛이 대신한 것
///
/// 예전에는 통계 카드 3장(자본·예정·사용) 위에 `남은 금액`(자본-예정-사용)과
/// `사용 후 잔액`(자본-사용)이 따로 놀아서, 두 값이 왜 다른지를 **물음표 툴팁**으로
/// 해명했다. 지금은 둘 다 같은 도넛의 구간이라 설명이 필요 없다 —
/// **다시 두 번째 "잔액" 숫자나 툴팁을 만들지 말 것.**
///
/// ## AI 조언 버튼은 없앴다
///
/// 눌러도 "준비중" 모달만 뜨는 미완성 기능이라 **앱 심사(애플 2.1)에 걸리고**,
/// 기대를 만들고 배신하는 자리였다. 시세 데이터가 쌓인 뒤 준비 패스의 유료
/// 기능으로 제대로 낸다 — **다시 "준비중" 상태로 되살리지 말 것.**
struct BudgetDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: BudgetDetailViewModel

    init(roomId: String? = nil) {
        _model = StateObject(wrappedValue: BudgetDetailViewModel(roomId: roomId))
    }

    var body: some View {
        // C안: 분홍 머리 면 + **흰 시트**. 점 그리드 배경은 이 화면에서 걷었다.
        ZStack {
            Color.white

            ScrollView {
                VStack(spacing: 0) {
                    head

                    if model.loading {
                        // 전역 스피너 대신 뼈대를 낸다 — 받기 전에 "없다" 고
                        // 말하지 않고, 받는 순간 높이도 튀지 않는다.
                        loadingSkeleton
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
                        // 도넛 하나가 예전의 통계 카드 3장 + `남은 금액`/`사용 후 잔액`
                        // 해명 툴팁을 대신한다. 두 값이 같은 그림의 다른 구간이라
                        // 물음표로 설명할 필요가 없어졌다.
                        BudgetDonutView(segments: model.donutSegments)

                        ZStack {
                            VStack(spacing: 0) {
                                Spacer().frame(height: 32)
                                CategoryTable(model: model)

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
        // 분홍 머리 면이 상태바 뒤까지 깔리도록 위로 넓힌다. 면은 스크롤 영역
        // **안**에 있어 내용과 함께 올라간다(웹 `data-mobile-head`).
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task { await model.load(env: env, guest: guest) }
    }

    /// 도넛과 표가 들어올 자리. 실제 화면과 같은 크기라 받는 순간 아래가 안 튄다.
    private var loadingSkeleton: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            SkeletonBox(width: 190, height: 190, corner: 95)
            Spacer().frame(height: 20)
            SkeletonBox(width: 220, height: 16)
            Spacer().frame(height: 24)
            ForEach(0..<4, id: \.self) { _ in
                VStack(spacing: 0) {
                    Hairline()
                    SkeletonBox(height: 18)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 웹 면 `rounded-b-[24px] px-6 pb-6 pt-4` — 가운데 "예산", 아래 초기 자본.
    ///
    /// **머리 면은 스크롤 영역 안에 있다**(웹 `data-mobile-head`). 내용과 함께
    /// 올라가야 작은 폰에서 표가 그만큼 더 보인다.
    ///
    /// 초기 자본을 여기서 말하므로 **아래 요약에서 다시 세지 않는다** —
    /// 도넛 밑 두 줄은 `사용률`·`사용 후 잔액`뿐이다.
    private var head: some View {
        BrandHead(corner: 24, horizontal: 24, top: 16, bottom: 24) {
            ZStack {
                Text("예산")
                    .font(WPFont.hak(17, .bold))
                    .tracking(-0.02 * 17)
                    .foregroundStyle(.white)

                HStack {
                    HeadIconButton(
                        systemName: "arrow.left",
                        label: "뒤로가기",
                        iconSize: 20
                    ) { dismiss() }
                    .offset(x: -8)
                    .accessibilityIdentifier("budget.back")

                    Spacer()

                    // 가이드는 아직 이식 전이라 자리를 비워 둔다.
                    // 눌러도 아무 일이 없는 버튼을 미리 두지 않는다.
                    Color.clear.frame(width: 36, height: 36)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer().frame(height: 12)
            Text("초기 자본")
                .font(WPFont.hak(13))
                .foregroundStyle(.white.opacity(0.8))

            Spacer().frame(height: 4)
            if model.loading {
                SkeletonBox(width: 176, height: 40, onBrand: true, corner: 8)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(withThousands(model.initialCapital))
                        .font(WPFont.hak(40, .bold))
                        .tracking(-0.04 * 40)
                    Text(" 만 원")
                        .font(WPFont.hak(18, .bold))
                        .tracking(-0.02 * 18)
                }
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
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

// MARK: - 카테고리별 표

/// 카테고리별 예산 표 — 웹 `SpendingAnalysis.tsx`.
///
/// 비율은 위의 도넛이 맡고 여기는 **정확한 값**을 맡는다. 예산·사용·남음을
/// 열로 세워야 서로 빼서 비교가 된다 — 예전에는 `사용 / 예산` 한 덩어리라
/// "얼마 남았나" 를 사람이 암산해야 했다.
///
/// **폰에서도 세 열을 세운다**(시안 C안 05). 58pt 짜리 숫자 열 셋은 375pt
/// 에서도 들어간다(이름 칸에 131pt 이 남는다). 예전에는 좁으면 한 덩어리로
/// 접혔는데, 그러면 폰에서만 다시 암산을 해야 했다.
///
/// **막대는 넓을 때만**이라 폰에는 없다 — 세 숫자가 이미 그 말을 한다.
private struct CategoryTable: View {
    @ObservedObject var model: BudgetDetailViewModel
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore

    /// 웹 `grid-cols-[minmax(0,1fr)_58px_58px_58px] gap-x-3`
    private let numberWidth: CGFloat = 58
    private let columnGap: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("카테고리별")
                    .font(WPFont.hak(18, .bold))
                    .tracking(-0.02 * 18)
                    .foregroundStyle(WPColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 고른 카테고리 풀기. **제목 줄에 함께 둬야** 무엇이 걸렸는지 보인다.
                if model.selectedCategory != nil {
                    Button {
                        Task { await model.clearCategory(env: env, guest: guest) }
                    } label: {
                        Text("필터 해제")
                            .font(WPFont.hak(12, .bold))
                            .foregroundStyle(WPColor.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(hex: 0xFFF2F6), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            headerRow

            if model.sortedCategories.isEmpty {
                Text("카테고리 데이터가 없습니다.")
                    .font(WPFont.hak(13))
                    .foregroundStyle(WPColor.gray400)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(model.sortedCategories) { item in
                    row(item)
                }
            }
        }
    }

    private var headerRow: some View {
        tableRow(
            name: Text("카테고리")
                .font(WPFont.hak(12, .bold))
                .foregroundStyle(WPColor.fgSubtle),
            cells: ["예산", "사용", "남음"].map { label in
                AnyView(
                    Text(label)
                        .font(WPFont.hak(12, .bold))
                        .foregroundStyle(WPColor.fgSubtle)
                )
            }
        )
    }

    private func row(_ item: CategoryChartItem) -> some View {
        let budget = item.total
        let used = item.used
        let left = budget - used
        let empty = budget == 0 && used == 0
        let selected = model.selectedCategory == item.categoryName
        let numberColor = empty ? WPColor.gray300 : WPColor.textPrimary

        return VStack(spacing: 0) {
            Hairline()
            tableRow(
                name: Text(item.categoryName)
                    .font(WPFont.hak(14))
                    .foregroundStyle(
                        selected ? WPColor.primary : (empty ? WPColor.gray400 : WPColor.textPrimary)
                    )
                    .lineLimit(1),
                cells: [
                    AnyView(numberCell(budget, color: numberColor)),
                    AnyView(numberCell(used, color: numberColor)),
                    // 남음만 굵게 — 이 화면에서 찾는 값이다.
                    AnyView(
                        numberCell(
                            left,
                            color: empty
                                ? WPColor.gray300
                                : (left < 0 ? BudgetDonutView.overColor : WPColor.textPrimary),
                            bold: true
                        )
                    ),
                ]
            )
        }
        .background(selected ? Color(hex: 0xFFF7FA) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await model.toggleCategory(item.categoryName, env: env, guest: guest) }
        }
    }

    private func numberCell(_ value: Int, color: Color, bold: Bool = false) -> some View {
        Text(withThousands(value))
            .font(WPFont.tmoney(13, bold ? .bold : .regular))
            .tracking(-0.02 * 13)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func tableRow(name: some View, cells: [AnyView]) -> some View {
        HStack(spacing: columnGap) {
            name.frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                cell.frame(width: numberWidth, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}


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

