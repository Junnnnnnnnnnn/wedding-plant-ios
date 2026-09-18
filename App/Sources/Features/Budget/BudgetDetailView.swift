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
                        // 도넛 하나가 예전의 통계 카드 3장 + `남은 금액`/`사용 후 잔액`
                        // 해명 툴팁을 대신한다. 두 값이 같은 그림의 다른 구간이라
                        // 물음표로 설명할 필요가 없어졌다.
                        BudgetDonutView(segments: model.donutSegments)

                        ZStack {
                            VStack(spacing: 0) {
                                Spacer().frame(height: 32)
                                AnalysisSection(model: model)

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



// MARK: - AI 버튼


// MARK: - 지출 분석

private struct AnalysisSection: View {
    @ObservedObject var model: BudgetDetailViewModel

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

