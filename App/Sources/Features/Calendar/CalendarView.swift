import SwiftUI
import UIKit
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/calendar/page.tsx` 의 **폰** 이식 — 시안 C안 02. 안드로이드 `ui/calendar/CalendarScreen.kt` 와 짝.
///
/// ```
/// [분홍 머리 면]  ‹ 2026년 9월 ›                 [+ 플랜 추가]
///                 [이번 달 예정 185만 원 / 지출 0만 원 · 일정 2개]
///                 [ 달력 | 보드 ]
/// 요일 · 격자(선 없음, 여백으로 구분)
/// 9월 12일 (토) 1                                     추가
///   회색 채움 카드
/// ```
///
/// - **격자 선을 전부 걷었다.** 셀마다 테두리를 두르면 날짜보다 선이 먼저 읽힌다.
/// - 날짜를 누르면 시트를 띄우지 않고 **달력 바로 아래 그날 목록**이 바뀐다.
///   시트를 한 겹 더 띄우면 달력이 가려져 다른 날로 옮기기 어렵다.
/// - **떠 있던 분홍 + 버튼은 없앴다.** 마지막 주를 가렸고 날짜 없이 추가를 시작하게 만들었다.
///   추가는 머리 줄의 `+ 플랜 추가` 와 그날 목록의 `추가` 가 맡고, 둘 다 **고른 날짜로** 시작한다.
/// - 엑셀·PDF 는 웹이 넓은 화면에서만 낸다 — 폰 트리에는 없다(안드로이드도 같음).
///   내보내기는 프로필의 준비 패스 도구·서류 보관함·예산에서 연다.
struct CalendarView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: CalendarViewModel
    @State private var addPlanDate: KstDate?
    @State private var showAddPlan = false
    /// 탭 셸 위에 플랜 추가를 연다(탭바가 남음 — Android `ADD_PLAN`). 셸 밖·다른 창 위면 예전처럼 전체 화면.
    @Environment(\.addPlanPresenter) private var addPlanPresenter
    @State private var openSchedule: ScheduleRef?
    /// 탭 셸 위에 일정 상세를 연다(탭바가 남음 — Android `SCHEDULE_DETAIL`). 셸 밖·다른 창 위면 예전처럼 전체 화면.
    @Environment(\.scheduleDetailPresenter) private var detailPresenter
    /// 머리 면이 지나갔는지 — 안드로이드 `headAway`. 지나가면 상태바 뒤에 흰 띠를 깐다.
    @State private var headAway = false
    /// 머리 면 높이(상태바 포함). 안드로이드는 240dp 로 못 박았지만, 그러면 iOS 상태바(47pt)에서는
    /// 면이 다 올라간 뒤 요일 줄이 띠 없이 시각 밑으로 겹쳐 지나가는 구간이 생긴다 — 면의 아래 끝이
    /// 상태바에 닿는 순간 깐다.
    @State private var headHeight: CGFloat = 240

    /// 홈의 `그 다음 · 전체` 로 쌓아 연 경우. 탭 화면은 닫을 것이 없어 X 를 두지 않는다
    /// (안드로이드는 시스템 뒤로가기가 있어 X 가 없다 — iOS 는 쌓아 연 화면에 나갈 길이 따로 필요하다).
    private let showsClose: Bool
    private let roomId: Int?

    init(roomId: Int? = nil, readOnly: Bool = false, showsClose: Bool = true) {
        self.showsClose = showsClose
        self.roomId = roomId
        _model = StateObject(
            wrappedValue: CalendarViewModel(roomId: roomId.map(String.init), readOnly: readOnly)
        )
    }

    private func openDetail(_ id: Int) {
        // 돌아오면 다시 받는다(안드로이드 `RefreshOnResume`) — 상세에서 완료·삭제했을 수 있다
        let opened = detailPresenter?.open(ScheduleDetailRequest(scheduleId: id, roomId: roomId) {
            Task { await model.refresh(env: env, guest: guest) }
        }) ?? false
        if !opened { openSchedule = ScheduleRef(id: id) }
    }

    var body: some View {
        ZStack(alignment: .top) {
        ScrollView {
            VStack(spacing: 0) {
                head
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headHeight = $0 }

                if let error = model.error {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(error)
                            .font(WPFont.hak(14))
                            .foregroundStyle(WPColor.danger)
                            .padding(24)
                        Button {
                            Task { await model.refresh(env: env, guest: guest) }
                        } label: {
                            Text("다시 시도")
                                .font(WPFont.hak(14, .bold))
                                .foregroundStyle(WPColor.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if model.view == .calendar {
                    VStack(spacing: 0) {
                        WeekdayRow()
                        grid
                    }
                    .padding(.horizontal, 8)

                    DayList(
                        date: model.selectedDate,
                        plans: model.plans(on: model.selectedDate),
                        // 처음 받는 동안(웹 `!calendarLoaded`) — 한 번 받은 뒤 달을 넘길 때는 해당 없음
                        loading: !model.loadedOnce,
                        readOnly: model.readOnly,
                        onOpen: { openDetail($0) },
                        onAdd: { startAdd() }
                    )
                } else {
                    BoardList(
                        loaded: model.upcomingLoaded,
                        groups: model.boardGroups,
                        onOpen: { openDetail($0) }
                    )
                }

                // 광고 ② — 스크롤 맨 끝 한 칸(달력 · 보드 모두). 날짜 칸 바로 밑은 피한다 — 날짜를 연달아
                // 누르다 광고를 누르면 무효 클릭이다. 처음 받는 동안·읽기 전용에는 넣지 않는다.
                // 아래 여백 40 — 탭바 가운데 `+` 원이 솟아 있어 24 로는 실제 틈이 모자랐다(안드로이드와 같음).
                if model.loadedOnce, !model.readOnly, env.isAuthenticated, env.isMyAdRoom(roomId) {
                    InlineBannerAd(placement: "calendar", bottom: 40)
                }
                // 광고가 없을 때도 마지막 줄(`이 날은 비어 있어요` 등)이 솟은 `+` 원 밑에 깔리지 않게
                // 굴려 올릴 자리를 둔다(목록 아래 24 + 16 = 광고 자리의 아래 여백 40).
                Spacer().frame(height: 16)
            }
            .background(GeometryReader { g in
                Color.clear.preference(key: CalendarScrollOffsetKey.self, value: g.frame(in: .named("calendar.scroll")).minY)
            })
        }
        .coordinateSpace(name: "calendar.scroll")
        .modifier(CalendarScrollReader { headAway = $0 > headHeight - wpStatusBarHeight })
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("calendar.scroll")

            // 안드로이드 `BrandStatusBar` — 머리 면이 지나간 뒤 상태바 뒤의 흰 띠. 없으면 굴린 날짜·글자가
            // 상태바 시각·아이콘 밑으로 겹쳐 지나간다.
            if headAway {
                BrandStatusStrip()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        // 분홍 머리 면이 상태바 뒤까지 깔리도록 스크롤 영역을 위로 넓힌다(홈과 같음).
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        // 처음부터 보드라 달력과 보드 목록을 함께 받는다(Android `init { refresh() }`)
        .task { await model.refresh(env: env, guest: guest) }
        // 시트 안에서는 NavigationStack 으로 push 할 수 없어 커버로 띄운다.
        // 돌아오면 다시 받는다(안드로이드 `RefreshOnResume`) — 상세에서 완료·삭제했을 수 있다.
        .fullScreenCover(item: $openSchedule, onDismiss: {
            Task { await model.refresh(env: env, guest: guest) }
        }) { schedule in
            ScheduleDetailView(scheduleId: schedule.id, roomId: roomId)
                .environmentObject(env)
                .environmentObject(guest)
        }
        .fullScreenCover(isPresented: $showAddPlan) {
            AddPlanView(
                roomId: roomId,
                initialDate: addPlanDate?.dateString
            ) {
                Task { await model.refresh(env: env, guest: guest) }
            }
            .environmentObject(env)
            .environmentObject(guest)
        }
    }

    /// **고른 날짜로 플랜 추가**(웹 `openAddPlan(toDateStr(selectedDateParams))`).
    private func startAdd() {
        addPlanDate = model.selectedDate
        let opened = addPlanPresenter?.open(AddPlanRequest(roomId: roomId, initialDate: model.selectedDate.dateString) {
            Task { await model.refresh(env: env, guest: guest) }
        }) ?? false
        if !opened { showAddPlan = true }
    }

    // MARK: - 머리 면

    /// 웹 d513e95 — 머리 **줄**은 좌우 16, 그 아래 분홍 면(합계·달력/보드)은 24.
    /// 두 덩이의 여백이 다르다. 화살표는 24×32, 제목 18, `오늘` 대신 `+ 플랜 추가`.
    private var head: some View {
        BrandHead(corner: 24, horizontal: 16, top: 16, bottom: 20) {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    MonthArrow(kind: .left, label: "이전 달", identifier: "calendar.prev") {
                        Task { await model.previousMonth(env: env, guest: guest) }
                    }
                    Text(verbatim: model.title)
                        .font(WPFont.hak(18, .bold))
                        .tracking(-0.36)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityIdentifier("calendar.title")
                    MonthArrow(kind: .right, label: "다음 달", identifier: "calendar.next") {
                        Task { await model.nextMonth(env: env, guest: guest) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 읽기 전용(READ)이면 감춘다 — 눌러야만 실패를 아는 버튼은 두지 않는다.
                if !model.readOnly {
                    Button(action: startAdd) {
                        HStack(spacing: 4) {
                            LucidePlus().stroke(Color.white, style: StrokeStyle(lineWidth: 2 * 14 / 24, lineCap: .round)).frame(width: 14, height: 14)
                            Text("플랜 추가")
                                .font(WPFont.hak(12, .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    .accessibilityLabel("플랜 추가")
                    .accessibilityIdentifier("calendar.add")
                }

                if showsClose {
                    Button { dismiss() } label: {
                        WPMaterialIcon(kind: .close)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                    .accessibilityLabel("닫기")
                    .accessibilityIdentifier("calendar.close")
                }
            }

            // 달을 넘길 때마다 그 달의 규모가 먼저 눈에 들어와야 해서 합계를 면 안으로 올렸다.
            VStack(alignment: .leading, spacing: 2) {
                if model.loading && model.byDay.isEmpty {
                    SkeletonBox(width: 144, height: 21, onBrand: true)
                    SkeletonBox(width: 176, height: 17, onBrand: true)
                } else {
                    let totals = model.monthTotals
                    Text(verbatim: "이번 달 예정 \(withThousands(totals.planned))만 원")
                        .font(WPFont.hak(14, .bold))
                        .foregroundStyle(.white)
                    Text(verbatim: "지출 \(withThousands(totals.spent))만 원 · 일정 \(totals.count)개")
                        .font(WPFont.hak(12))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.top, 12)

            // 달력 ↔ 보드. 웹 `mt-4 grid grid-cols-2 gap-0.5 rounded-[10px] bg-white/20 p-[3px]`
            HStack(spacing: 2) {
                // 아이콘을 붙인 이름(Android 8c1068b `📅 달력` · `🗂️ 보드`, 요청서 02 — 사용자가 고른 글자 그대로)
                viewTab(.calendar, "📅 달력", identifier: "calendar.view.calendar")
                viewTab(.board, "🗂️ 보드", identifier: "calendar.view.board")
            }
            .padding(3)
            .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.top, 16)
        }
    }

    private func viewTab(_ view: CalendarViewModel.MobileView, _ label: String, identifier: String) -> some View {
        let selected = model.view == view
        return Button {
            Task { await model.setView(view, env: env, guest: guest) }
        } label: {
            Text(label)
                .font(WPFont.hak(13, selected ? .bold : .regular))
                .foregroundStyle(selected ? WPColor.primary : Color.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(selected ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 격자

    private var grid: some View {
        let cells = model.grid
        let today = KstDate.today()

        return VStack(spacing: 0) {
            ForEach(0..<(CalendarGrid.cellCount / 7), id: \.self) { row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let date = cells[row * 7 + column]
                        DayCell(
                            date: date,
                            columnIndex: column,
                            inCurrentMonth: model.inCurrentMonth(date),
                            isToday: date == today,
                            selected: date == model.selectedDate,
                            plans: model.plans(on: date)
                        ) {
                            Task { await model.select(date, env: env, guest: guest) }
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 굴린 거리. iOS 18 부터는 스크롤 뷰가 직접 알려 주는 값을 쓴다(예산 상세와 같은 이유).
private struct CalendarScrollReader: ViewModifier {
    let onChange: (CGFloat) -> Void
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in onChange(y) }
        } else {
            content.onPreferenceChange(CalendarScrollOffsetKey.self) { onChange(-$0) }
        }
    }
}

/// `fullScreenCover(item:)` 은 Identifiable 을 요구한다. Int 를 그대로 넘길 수 없어 감싼다.
private struct ScheduleRef: Identifiable, Hashable {
    var id: Int
}

// MARK: - 부품

/// lucide `Plus`(`M5 12h14`, `M12 5v14`) — 안드로이드 `LucideIcons.Plus`. 24 격자를 받은 칸에 맞춘다.
private struct LucidePlus: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 24
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 5 * unit, y: rect.minY + 12 * unit))
        p.addLine(to: CGPoint(x: rect.minX + 19 * unit, y: rect.minY + 12 * unit))
        p.move(to: CGPoint(x: rect.minX + 12 * unit, y: rect.minY + 5 * unit))
        p.addLine(to: CGPoint(x: rect.minX + 12 * unit, y: rect.minY + 19 * unit))
        return p
    }
}

/// 머리 줄의 달 화살표 — 안드로이드 `HeadIconButton(width 24, size 32, icon 20)`, Material ChevronLeft/Right.
private struct MonthArrow: View {
    var kind: WPMaterialIcon.Kind
    var label: String
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            WPMaterialIcon(kind: kind)
                .frame(width: 20, height: 20)
                .foregroundStyle(.white)
                .frame(width: 24, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

/// 일=`#fa342c`, 토=`#217cf9`, 나머지 `#868b94`
private func weekdayColor(_ index: Int) -> Color {
    switch index {
    case 0: return WPColor.critical
    case 6: return WPColor.informative
    default: return WPColor.fgSubtle
    }
}

private struct WeekdayRow: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(CalendarGrid.weekdayLabels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(WPFont.hak(12, .bold))
                    .foregroundStyle(weekdayColor(index))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
    }
}

/// 웹: `min-h-[68px] rounded-lg p-1`, 다른 달은 `opacity-40`, 오늘은 22pt 분홍 원.
/// 일정 칩은 `text-[9.5px] rounded bg-[#fff1f7] text-[#cc1873]`, 완료는 `bg-[#f3f4f5] text-[#868b94]` + 취소선.
///
/// **고른 날은 칸이 아니라 숫자에 표시한다**(웹과 같은 B안) — 오늘 + 고름은 채운 원 + 흰 틈 + 바깥 링.
private struct DayCell: View {
    var date: KstDate
    var columnIndex: Int
    var inCurrentMonth: Bool
    var isToday: Bool
    var selected: Bool
    var plans: [CalendarPlanItem]
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                dayNumber

                VStack(spacing: 2) {
                    ForEach(plans.prefix(2)) { plan in
                        PlanChip(plan: plan)
                    }
                }

                if plans.count > 2 {
                    Text(verbatim: "+\(plans.count - 2)")
                        .font(WPFont.hak(10, .black))
                        .foregroundStyle(WPColor.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                        .background(WPColor.primary.opacity(0.04), in: Capsule())
                        .overlay(Capsule().stroke(WPColor.primary.opacity(0.08), lineWidth: 1))
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .top)
            .opacity(inCurrentMonth ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar.day.\(date.dateString)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var markToday: Bool { isToday && inCurrentMonth }
    private var markSelected: Bool { selected && inCurrentMonth }

    /// **자리를 26pt 로 고정한다.** 오늘을 고른 경우 채운 원(22) 바깥에 링이 한 겹 더 붙는데,
    /// 그때만 키우면 그 줄만 내려앉아 달력이 들썩인다.
    private var dayNumber: some View {
        ZStack {
            if markToday && markSelected {
                Circle().strokeBorder(WPColor.primary, lineWidth: 1.5).frame(width: 26, height: 26)
            }
            if markToday {
                Circle().fill(WPColor.primary).frame(width: 22, height: 22)
            } else if markSelected {
                Circle().strokeBorder(WPColor.primary, lineWidth: 1.5).frame(width: 22, height: 22)
            }
            Text(verbatim: "\(date.day)")
                .font(WPFont.hak(13, markToday || markSelected ? .bold : .regular))
                .foregroundStyle(numberColor)
                .fixedSize()
        }
        .frame(width: 26, height: 26)
    }

    private var numberColor: Color {
        if !inCurrentMonth { return WPColor.fgDisabled }
        if markToday { return .white }
        if markSelected { return WPColor.primaryPressed }
        if columnIndex == 0 { return WPColor.critical }
        if columnIndex == 6 { return WPColor.informative }
        return WPColor.fgNeutral
    }
}

private struct PlanChip: View {
    var plan: CalendarPlanItem

    var body: some View {
        let done = plan.isCompleted
        // 제목은 사용자 입력값이라 Tmoney (웹 `font-user-content`)
        Text(plan.title)
            .font(WPFont.tmoney(9.5))
            .strikethrough(done)
            .foregroundStyle(done ? WPColor.fgSubtle : WPColor.brand700)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                done ? WPColor.basement : WPColor.brand100,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
    }
}

/// 결제가 일정 완료와 **어긋날 때만** 붙는 작은 표(`결제함`). 안드로이드 `PaymentMismatchBadge`.
private struct PaymentMismatchBadge: View {
    var mismatch: PaymentMismatch?
    var fontSize: CGFloat = 11

    var body: some View {
        if let mismatch {
            Text(mismatch.label)
                .font(WPFont.hak(fontSize, .bold))
                .foregroundStyle(WPColor.mismatchText)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(WPColor.mismatchBackground, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}

/// 사용자가 적은 제목 한 줄 — 안드로이드 Tmoney Regular + 합성 볼드, 넘치면 말줄임.
///
/// `WPTmoneyText` 는 늘 제 폭을 주장해 긴 제목이 카드 밖으로 나가므로, 받은 폭에 맞춰 자른다.
private struct TmoneyLine: UIViewRepresentable {
    let text: String
    var size: CGFloat
    var bold = false
    var color: Color
    var tracking: CGFloat = 0
    var lineHeight: CGFloat = 0

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let ink = UIColor(color)
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: WPTypeface.tmoney.uiFont(size, .regular), .foregroundColor: ink,
            .strokeColor: ink, .strokeWidth: bold ? -2.5 : 0, .kern: tracking,
        ])
        label.accessibilityLabel = text
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let natural = uiView.intrinsicContentSize.width
        let width = proposal.width.map { min($0, natural) } ?? natural
        // 안드로이드는 줄높이(1.5em)를 주되 첫 줄 위·끝 줄 아래를 잘라(LineHeightStyle Trim.Both)
        // 한 줄 글자는 글꼴 본래 높이만 차지한다 — 같은 높이를 쓴다.
        return CGSize(width: width, height: uiView.font.lineHeight)
    }
}

// MARK: - 그날 목록

/// 시안 C안 02 의 그날 목록 — 달력 바로 아래. 웹 `px-4 pb-6 pt-5`
private struct DayList: View {
    var date: KstDate
    var plans: [CalendarPlanItem]
    var loading: Bool
    var readOnly: Bool
    var onOpen: (Int) -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(
                title: date.monthDayWeekText,
                // 받기 전에는 개수도 말하지 않는다 — "0" 이 먼저 떴다가 바뀌었다(웹 f6f0405)
                meta: loading ? nil : "\(plans.count)",
                titleSize: 16,
                actionLabel: readOnly ? nil : "추가",
                onAction: onAdd,
                actionIdentifier: "calendar.dayAdd"
            )
            .padding(.horizontal, 4)

            if loading {
                // **받기 전에 "비어 있다" 고 말하지 않는다**(웹 f6f0405). 받는 동안은 카드 뼈대 둘(76).
                VStack(spacing: 8) {
                    SkeletonBox(height: 76, corner: 16)
                    SkeletonBox(height: 76, corner: 16)
                }
                .padding(.top, 12)
            } else if plans.isEmpty {
                Text("이 날은 비어 있어요")
                    .font(WPFont.hak(14))
                    .foregroundStyle(WPColor.fgSubtle)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(plans) { plan in
                        DayPlanCard(plan: plan) { onOpen(plan.id) }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
}

/// 회색 채움 카드 — 제목 / 카테고리 · 결제함 · 시각 · 금액.
private struct DayPlanCard: View {
    var plan: CalendarPlanItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                TmoneyLine(text: plan.title, size: 16, bold: true, color: WPColor.fgNeutral,
                           tracking: -0.16, lineHeight: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 0) {
                    if !plan.categoryName.isEmpty {
                        CategoryTag(name: plan.categoryName)
                            .padding(.trailing, 8)
                    }
                    PaymentMismatchBadge(mismatch: plan.paymentMismatch)
                        .padding(.trailing, plan.paymentMismatch == nil ? 0 : 8)
                    Text(formatKoreanTime(plan.startTime))
                        .font(WPFont.hak(13))
                        .foregroundStyle(WPColor.fgMuted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AmountText(amount: plan.amount ?? 0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar.plan.\(plan.id)")
    }
}

// MARK: - 보드

/// 보드 뷰 — 웹 폰의 `보드` 와 **같은 규칙**으로 묶는다(``CalendarGrid/boardGroups(_:)``).
/// 날짜 미정이 맨 앞, 그 뒤로 달 순서, 묶음 안에서 완료한 것은 아래로.
private struct BoardList: View {
    var loaded: Bool
    var groups: [(label: String, items: [ScheduleItem])]
    var onOpen: (Int) -> Void

    /// 카드를 한 장씩 짓는다(Android 8c1068b `LazyColumn`, 요청서 08). 화면 전체(머리 면 · 달력)를 LazyVStack 으로 감싸면
    /// 달력 모드에서 스크롤 영역의 접근성 질의가 끝나지 않아(UI 테스트 223초 시간 초과) 게으른 자리는 보드 목록으로 좁힌다.
    var body: some View {
        LazyVStack(spacing: 0) { rows }
    }

    @ViewBuilder private var rows: some View {
        Color.clear.frame(height: 16)
        if !loaded {
            // 뼈대도 카드 모양으로(웹 min-h-20 · r15 · 10 간격)
            // 키는 Android 처럼 갈래마다 따로(`board-loading-N` · `board-plan-id`) — 한 LazyVStack 안에서 뼈대(0…4)와 일정 id 가
            // 같은 숫자면 받은 뒤의 카드가 뼈대 모양을 물려받아 빈 회색 상자로 남았다
            ForEach((0..<5).map { "board-loading-\($0)" }, id: \.self) { _ in
                SkeletonBox(height: 80, corner: 15).padding(.top, 10).padding(.horizontal, 16)
            }
        } else if groups.isEmpty {
            Text("아직 일정이 없어요")
                .font(WPFont.hak(14))
                .foregroundStyle(WPColor.fgSubtle)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            ForEach(Array(groups.enumerated()), id: \.element.label) { index, group in
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(group.label)
                        .font(WPFont.hak(13.5, .bold))
                        .foregroundStyle(WPColor.fgNeutral)
                    Text(verbatim: "\(group.items.count)개")
                        .font(WPFont.hak(11.5))
                        .foregroundStyle(WPColor.passSheetFaint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, index == 0 ? 4 : 20)
                .padding(.bottom, 4)

                ForEach(group.items.map { ("board-plan-\($0.id)", $0) }, id: \.0) { _, item in
                    DateTileRow(item: item) { onOpen(item.id) }
                        .padding(.top, 10)
                        .padding(.horizontal, 16)
                }
            }
        }
        Color.clear.frame(height: 24)
    }
}

/// 웹 `app/components/PlanDateTileItem.tsx` — 날짜 타일 + 제목 · 칩 · 상태 + 금액.
/// `min-h-20 rounded-[15px] border-[#eee8ed] bg-white px-3 py-3 gap-3` (안드로이드 `DateTileRow`)
private struct DateTileRow: View {
    var item: ScheduleItem
    var onTap: () -> Void

    var body: some View {
        let date = KstDate(dateString: item.startDate ?? "")
        let completed = item.isScheduleCompleted
        let amount = item.amount ?? 0
        let muted = completed || date == nil
        let ink = muted ? WPColor.dateTileMutedInk : WPColor.dateTileInk

        Button(action: onTap) {
            HStack(spacing: 12) {
                // 날짜 타일 `min-h-14 w-11 rounded-[10px] py-1 text-[10px]` — 세로로 꽉 찬다(self-stretch)
                VStack(spacing: 0) {
                    Text(verbatim: date.map { "\($0.month)월" } ?? "날짜")
                        .font(WPFont.hak(10))
                        .foregroundStyle(ink)
                    TmoneyLine(text: date.map { String(format: "%02d", $0.day) } ?? "—",
                               size: 21, bold: true, color: ink, lineHeight: 21)
                        .fixedSize()
                        .padding(.vertical, 2)
                    if date == nil {
                        Text("미정").font(WPFont.hak(10)).foregroundStyle(ink)
                    }
                }
                .padding(.vertical, 4)
                .frame(width: 44)
                .frame(minHeight: 56, maxHeight: .infinity)
                .background(muted ? WPColor.dateTileMutedFill : WPColor.dateTileFill,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    TmoneyLine(text: item.title, size: 15, bold: true,
                               color: completed ? WPColor.dateTileDoneTitle : WPColor.fgNeutral,
                               lineHeight: 20.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 0) {
                        if !item.categoryName.isEmpty {
                            Text(item.categoryName)
                                .font(WPFont.hak(10))
                                .foregroundStyle(WPColor.dateTileCategory)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(WPColor.dateTileFill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .padding(.trailing, 6)
                        }
                        Text(completed ? "완료" : (date != nil ? "예정" : "계획 중"))
                            .font(WPFont.hak(11))
                            .foregroundStyle(WPColor.dateTileStatus)
                            .fixedSize()
                        PaymentMismatchBadge(mismatch: item.paymentMismatch, fontSize: 10)
                            .padding(.leading, item.paymentMismatch == nil ? 0 : 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if amount > 0 {
                    TmoneyLine(text: "\(withThousands(amount))만 원", size: 16, bold: true,
                               color: WPColor.fgNeutral, lineHeight: 24)
                        .fixedSize()
                } else {
                    Text("금액 미정")
                        .font(WPFont.hak(13))
                        .foregroundStyle(WPColor.dateTileNoAmount)
                        .fixedSize()
                }
            }
            .padding(12)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(WPColor.dateTileBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
