import SwiftUI
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/budget-detail/page.tsx` 의 **폰** 이식 — 안드로이드 `ui/budget/BudgetDetailScreen.kt` 와 같은 화면(시안 C안 05).
///
/// ```
/// [분홍 머리 면]  ⌂        예산
///                 초기 자본
///                 5,000 만 원                     ← 40pt
/// 도넛 · 범례 · 사용률 / 사용 후 잔액              ← 카드 없이 시트 한 장
/// [🔒 예산·일정 엑셀로 받기]                        ← 도넛 요약 바로 아래(웹 cb95596)
/// 카테고리별   (카테고리 | 예산 | 사용 | 남음)      ← 폰에서도 세 열
/// 항목 N  [ 예정 | 사용 ]                          ← 반씩 나눈 회색 세그먼트
/// 구분선 목록
/// ```
///
/// 글자의 줄 높이는 안드로이드 Compose 기본(글자 크기 × 1.5)을 `wpTypography` 로 맞춘다 —
/// SwiftUI 기본 줄 높이로 두면 줄마다 몇 pt 씩 낮아져 표가 안드로이드보다 짧아진다.
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
/// 기대를 만들고 배신하는 자리였다. **다시 "준비중" 상태로 되살리지 말 것.**
struct BudgetDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: BudgetDetailViewModel
    /// 머리 면이 지나갔는지 — 안드로이드 `headAway`(scroll > 200). 지나가면 상태바 뒤에 흰 띠를 깐다.
    @State private var headAway = false

    init(roomId: String? = nil) {
        _model = StateObject(wrappedValue: BudgetDetailViewModel(roomId: roomId))
    }

    var body: some View {
        // C안: 분홍 머리 면 + **흰 시트**. 점 그리드 배경은 이 화면에서 걷었다.
        ZStack(alignment: .top) {
            Color.white

            ScrollView {
                VStack(spacing: 0) {
                    head

                    if model.loading {
                        // 받기 전에 "없다" 고 말하지 않는다 — 실제 화면과 같은 짜임의 뼈대.
                        loadingSkeleton
                    } else if model.detail == nil {
                        errorState(model.errorMessage ?? "데이터가 없습니다.")
                    } else {
                        content
                    }

                    if !model.loading, model.detail != nil, !model.isGuest,
                       model.usedTotal + model.plannedTotal > 0, env.isMyAdRoom(model.roomId.flatMap(Int.init)) {
                        InlineBannerAd(placement: "budget")
                    }
                    // 안드로이드 본문 `padding(vertical = 16)` 아래 + 스크롤 `padding(bottom = 24)`
                    Spacer().frame(height: 24)
                }
                .background(GeometryReader { g in
                    Color.clear.preference(key: BudgetScrollOffsetKey.self, value: g.frame(in: .named("budget.scroll")).minY)
                })
            }
            .coordinateSpace(name: "budget.scroll")
            .modifier(BudgetScrollReader { headAway = $0 > 200 })
            .accessibilityIdentifier("budget.scroll")

            // 안드로이드 `BrandStatusBar` — 머리 면이 지나간 뒤 상태바 뒤의 흰 띠
            if headAway {
                BrandStatusStrip()
            }
        }
        // 분홍 머리 면이 상태바 뒤까지 깔리도록 위로 넓힌다. 면은 스크롤 영역
        // **안**에 있어 내용과 함께 올라간다(웹 `data-mobile-head`).
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task { await model.load(env: env, guest: guest) }
    }

    // MARK: - 본문

    private var content: some View {
        VStack(spacing: 0) {
            // 도넛 하나가 예전의 통계 카드 3장 + `남은 금액`/`사용 후 잔액` 해명 툴팁을 대신한다.
            BudgetDonutView(segments: model.donutSegments)

            // 웹과 같은 자리 — **도넛 요약 바로 아래**. 돈 이야기를 하는 화면이라 양가에 보여 줄 표를 받는 자리다.
            if !model.isGuest {
                BudgetExportButton(roomId: model.roomId.flatMap(Int.init))
            }

            Spacer().frame(height: 24)

            ZStack {
                VStack(spacing: 0) {
                    CategoryTable(model: model)

                    Spacer().frame(height: 24)
                    itemsHeader
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    Segment(model: model)
                    Spacer().frame(height: 12)
                    ExpenseList(items: model.items, emptyMessage: emptyMessage)
                }
                // 웹: 비로그인은 blur + pointer-events-none
                .blur(radius: model.isGuest ? 6 : 0)
                .allowsHitTesting(!model.isGuest)

                if model.isGuest {
                    Button {
                        env.isAuthenticated = false
                    } label: {
                        Text("로그인이 필요한 서비스 입니다")
                            .wpTypography(14, .bold)
                            .foregroundStyle(WPColor.stone700)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 16)
    }

    /// `항목 N` — 카테고리를 고르면 `웨딩홀 항목 N`
    private var itemsHeader: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(model.selectedCategory.map { "\($0) 항목" } ?? "항목")
                .wpTypography(18, .bold)
                .tracking(-0.36)
                .foregroundStyle(WPColor.textPrimary)
            Text("\(model.items.count)")
                .wpTypography(13)
                .foregroundStyle(WPColor.fgSubtle)
                .padding(.bottom, 2)
            Spacer(minLength: 0)
        }
    }

    /// 웹 f6f0405 — '사용' 은 결제 기준이고(완료가 아님), 카테고리를 고르지 않았으면 카테고리 이야기를 하지 않는다.
    private var emptyMessage: String {
        if model.tab == .used { return "결제한 항목이 없습니다." }
        if model.selectedCategory != nil { return "이 카테고리에 예정된 항목이 없습니다." }
        return "예정된 항목이 없습니다."
    }

    /// 실제 화면(도넛 → 표 → 항목)과 같은 짜임의 뼈대
    private var loadingSkeleton: some View {
        VStack(spacing: 0) {
            SkeletonBox(width: 190, height: 190, corner: 95)
            Spacer().frame(height: 24)
            SkeletonBox(width: 240, height: 16)
            Spacer().frame(height: 32)
            ForEach(0..<3, id: \.self) { _ in
                SkeletonBox(height: 20)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - 머리 면

    /// 웹 면 `rounded-b-[24px] px-6 pb-6 pt-4` — 가운데 "예산", 아래 초기 자본 40pt.
    ///
    /// 초기 자본을 여기서 말하므로 **아래 요약에서 다시 세지 않는다** —
    /// 도넛 밑 두 줄은 `사용률`·`사용 후 잔액`뿐이다.
    private var head: some View {
        BrandHead(corner: 24, horizontal: 24, top: 16, bottom: 24) {
            ZStack {
                Text("예산")
                    .wpTypography(17, .bold)
                    .tracking(-0.34)
                    .foregroundStyle(.white)

                HStack {
                    // 웹·안드로이드와 같은 집 아이콘 '홈으로 가기' — 이 화면은 홈의 예산 카드에서만 들어온다
                    Button { dismiss() } label: {
                        WPLucideIcon(paths: BudgetIcons.house, size: 20, color: .white)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("홈으로 가기")
                    .accessibilityIdentifier("budget.back")
                    .offset(x: -8)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)

            Spacer().frame(height: 12)
            Text("초기 자본")
                .wpTypography(13)
                .foregroundStyle(.white.opacity(0.8))

            Spacer().frame(height: 4)
            if model.loading {
                SkeletonBox(width: 176, height: 40, onBrand: true, corner: 8)
            } else {
                (Text(withThousands(model.initialCapital)).font(WPFont.hak(40, .bold)).tracking(-1.6)
                    + Text(" 만 원").font(WPFont.hak(18, .bold)).tracking(-0.36))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    // 안드로이드 `lineHeight = 40.sp` — 줄 상자가 글자 크기와 같다
                    .frame(height: 40)
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 0) {
            Text(message)
                .wpTypography(16, .semibold)
                .foregroundStyle(WPColor.primary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 16)
            Button {
                Task { await model.load(env: env, guest: guest) }
            } label: {
                Text("다시 시도")
                    .wpTypography(14, .bold)
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

private struct BudgetScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 굴린 거리. iOS 18 부터는 스크롤 뷰가 직접 알려 주는 값을 쓴다 — 내용 안의 GeometryReader 기준은
/// 굴리는 동안 갱신되지 않을 때가 있었다(흰 띠가 안 깔림).
private struct BudgetScrollReader: ViewModifier {
    let onChange: (CGFloat) -> Void
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in onChange(y) }
        } else {
            content.onPreferenceChange(BudgetScrollOffsetKey.self) { onChange(-$0) }
        }
    }
}

/// 안드로이드 `LucideIcons.House` · `Icons.Outlined.Lock` 원본 경로
private enum BudgetIcons {
    static let house = [
        "M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8",
        "M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",
    ]
    static let lockOutlined = [
        "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM9 6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9V6zm9 14H6V10h12v10zm-6-3c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2z",
    ]
}

// MARK: - 엑셀 받기

/// 안드로이드 `PassExportButton` — 흰 면 · `#f0e3ea` 테두리 · 가운데 `예산·일정 엑셀로 받기`.
/// 패스가 없으면 자물쇠를 앞에 달고 준비 패스 소개를 연다. **패스를 받기 전에는 내지 않는다**
/// (산 사람에게 자물쇠가 한 번 번쩍이지 않게 — 안드로이드 `if (pass.loading) return`).
private struct BudgetExportButton: View {
    let roomId: Int?
    @EnvironmentObject private var env: AppEnvironment
    @State private var pass: PassState?
    @State private var showExport = false
    @State private var showPass = false

    private let ink = Color(hex: 0x6B6570)

    var body: some View {
        // 받기 전에도 자리(높이 0)를 두어 `.task` 가 돈다 — 빈 Group 은 나타나지 않아 받기가 시작되지 않았다.
        ZStack {
            Color.clear.frame(height: 0)
            if let pass {
                Button {
                    if pass.hasPass { showExport = true } else { showPass = true }
                } label: {
                    HStack(spacing: 8) {
                        if !pass.hasPass {
                            WPMaterialPathIcon(paths: BudgetIcons.lockOutlined, size: 14, color: ink)
                        }
                        Text("예산·일정 엑셀로 받기")
                            .wpTypography(14, .bold)
                            .foregroundStyle(ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: 0xF0E3EA), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("budget.export")
                // 웹 cb95596 `mx-4 mt-4`
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .task(id: roomId) { await load() }
        .sheet(isPresented: $showExport) { CalendarExportSheet(roomId: roomId) }
        .fullScreenCover(isPresented: $showPass, onDismiss: { Task { await load() } }) { PassView(roomId: roomId) }
    }

    private func load() async {
        // 방이 없는 혼자 쓰는 사람은 패스도 없다 — 자물쇠를 단 채 내서 준비 패스 소개로 가게 한다(Android `PassExportButton` 은
        // 방이 없어도 받기를 마치고 잠긴 단추를 낸다). 예전에는 여기서 돌아가 단추가 영영 안 떴다(2026-10-28 iOS QA BUD-04).
        guard let roomId else { pass = PassState(hasPass: false); return }
        if let state: PassState = try? await env.api.send(Endpoint.pass(roomId: roomId)) { pass = state }
    }
}

// MARK: - 카테고리별 표

/// 카테고리별 예산 표 — 예산·사용·남음을 **폰에서도 세 열**로 세운다(58pt 열 셋).
/// 한 덩어리 `사용 / 예산` 이면 "얼마 남았나" 를 사람이 암산해야 한다. 막대는 넓을 때만이라 폰에는 없다.
private struct CategoryTable: View {
    @ObservedObject var model: BudgetDetailViewModel
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore

    /// 웹 `grid-cols-[minmax(0,1fr)_58px_58px_58px] gap-x-3`
    private let numberWidth: CGFloat = 58
    private let columnGap: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("카테고리별")
                    .wpTypography(18, .bold)
                    .tracking(-0.36)
                    .foregroundStyle(WPColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 고른 카테고리 풀기. **제목 줄에 함께 둬야** 무엇이 걸렸는지 보인다.
                if model.selectedCategory != nil {
                    Button {
                        Task { await model.clearCategory(env: env, guest: guest) }
                    } label: {
                        Text("필터 해제")
                            .wpTypography(12, .bold)
                            .foregroundStyle(WPColor.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(hex: 0xFFF2F6), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("budget.clearFilter")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            tableRow(
                name: Text("카테고리").wpTypography(12, .bold).foregroundStyle(WPColor.fgSubtle),
                cells: ["예산", "사용", "남음"].map { label in
                    AnyView(Text(label).wpTypography(12, .bold).foregroundStyle(WPColor.fgSubtle))
                }
            )

            if model.sortedCategories.isEmpty {
                Text("카테고리 데이터가 없습니다.")
                    .wpTypography(13)
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
                    .wpTypography(14)
                    .foregroundStyle(selected ? WPColor.primary : (empty ? WPColor.gray400 : WPColor.textPrimary))
                    .lineLimit(1),
                cells: [
                    AnyView(numberCell(budget, color: numberColor)),
                    AnyView(numberCell(used, color: numberColor)),
                    // 남음만 굵게 — 이 화면에서 찾는 값이다.
                    AnyView(numberCell(
                        left,
                        color: empty ? WPColor.gray300 : (left < 0 ? BudgetDonutView.overColor : WPColor.textPrimary),
                        bold: true
                    )),
                ]
            )
        }
        .background(selected ? Color(hex: 0xFFF7FA) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await model.toggleCategory(item.categoryName, env: env, guest: guest) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("budget.category.\(item.categoryName)")
    }

    /// 안드로이드 `NumCell` — Tmoney 13, 남음만 굵게(Regular 파일에 합성한 굵기 — `WPTmoneyText`).
    private func numberCell(_ value: Double, color: Color, bold: Bool = false) -> some View {
        WPTmoneyText(text: withThousands(value), size: 13, bold: bold, color: UIColor(color), lineHeight: 19.5, tracking: -0.26)
            .fixedSize()
    }

    /// 웹 `grid-cols-[minmax(0,1fr)_58px_58px_58px] gap-x-3 px-4 py-3`
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

// MARK: - 예정 / 사용

/// 세그먼트 — 폰은 **한 줄을 반씩**. 제목 옆 작은 알약은 손가락으로 누르기 좁았다(안드로이드 `Segment`).
private struct Segment: View {
    @ObservedObject var model: BudgetDetailViewModel
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BudgetDetailViewModel.Tab.allCases) { tab in
                let active = model.tab == tab
                Button {
                    Task { await model.setTab(tab, env: env, guest: guest) }
                } label: {
                    Text(tab.label)
                        .wpTypography(13, .bold)
                        .foregroundStyle(active ? WPColor.textPrimary : WPColor.fgSubtle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("budget.tab.\(tab.rawValue)")
            }
        }
        .padding(3)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
    }
}

/// 항목 목록 — SEED ListItem 처럼 **구분선으로만** 나눈다. 아이콘 타일은 넓은 화면 전용이고
/// (줄마다 같은 분홍 타일이 제목보다 먼저 읽혔다), 오른쪽은 금액 한 줄이다.
private struct ExpenseList: View {
    var items: [ScheduleItem]
    var emptyMessage: String

    var body: some View {
        if items.isEmpty {
            Text(emptyMessage)
                .wpTypography(13)
                .foregroundStyle(WPColor.gray400)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .wpTypography(14)
                                    .foregroundStyle(WPColor.fgNeutral)
                                    .lineLimit(1)
                                Text(item.categoryName)
                                    .wpTypography(12)
                                    .foregroundStyle(WPColor.fgSubtle)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            let amount = item.amount ?? 0
                            Text(amount > 0 ? "\(withThousands(amount))만 원" : "미정")
                                .wpTypography(13)
                                .foregroundStyle(WPColor.fgSubtle)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Hairline()
                    }
                }
            }
        }
    }
}
