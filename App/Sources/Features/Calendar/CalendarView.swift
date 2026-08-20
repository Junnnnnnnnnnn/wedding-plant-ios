import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/calendar/page.tsx` 이식.
///
/// ```
/// "2026년 8월"  text-2xl font-black        [<] [>] | [X]
/// 요일 7칸 (일=빨강, 토=파랑, 나머지 회색)
/// 42칸 격자 · 각 칸 min-h-100 · 플랜 최대 2개 + "+N"
/// 우하단 플로팅 + 버튼
/// 날짜를 누르면 그 날 플랜 목록 시트
/// ```
///
/// - Note: 이 화면만 배경이 **흰색**이다. 다른 화면의 점 그리드 배경(`WPScreenBackground`)을
///   쓰지 않는다 — 웹도 `bg-white` 다.
struct CalendarView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: CalendarViewModel
    @State private var selectedDate: KstDate?
    @State private var addPlanDate: KstDate?
    @State private var showAddPlan = false
    @State private var openSchedule: ScheduleRef?

    private let roomId: Int?

    init(roomId: Int? = nil, readOnly: Bool = false) {
        self.roomId = roomId
        _model = StateObject(
            wrappedValue: CalendarViewModel(roomId: roomId.map(String.init), readOnly: readOnly)
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    WeekdayRow()
                    grid
                    // 플로팅 버튼에 마지막 주가 가리지 않도록 (웹 `pb-24`)
                    Spacer().frame(height: 96)
                }
            }
            .accessibilityIdentifier("calendar.scroll")

            if !model.readOnly {
                AddFloatingButton {
                    addPlanDate = nil
                    showAddPlan = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden()
        .task { await model.load(env: env, guest: guest) }
        .sheet(item: $selectedDate) { date in
            DayPlansSheet(
                date: date,
                plans: model.plans(on: date),
                readOnly: model.readOnly,
                onClose: { selectedDate = nil },
                onOpen: { id in
                    selectedDate = nil
                    // 게스트 항목(음수 id)은 상세 조회 API 가 없다. 웹도 같은 상황이라 그대로 둔다.
                    openSchedule = ScheduleRef(id: id)
                },
                onAdd: {
                    selectedDate = nil
                    addPlanDate = date
                    showAddPlan = true
                }
            )
            .environmentObject(env)
            .environmentObject(guest)
        }
        // 시트 안에서는 NavigationStack 으로 push 할 수 없어 커버로 띄운다.
        // 상세 화면은 자체 뒤로가기(dismiss)를 갖고 있어 그대로 동작한다.
        .fullScreenCover(item: $openSchedule) { schedule in
            ScheduleDetailView(scheduleId: schedule.id)
                .environmentObject(env)
                .environmentObject(guest)
        }
        .fullScreenCover(isPresented: $showAddPlan) {
            AddPlanView(
                roomId: roomId,
                initialDate: addPlanDate?.dateString
            ) {
                Task { await model.load(env: env, guest: guest) }
            }
            .environmentObject(env)
            .environmentObject(guest)
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 0) {
            Text(model.title)
                .font(WPFont.hak(24, .black))
                .foregroundStyle(WPColor.textPrimary)

            Spacer(minLength: 8)

            RoundIconButton(symbol: "chevron.left", label: "이전 달", tint: WPColor.gray600) {
                Task { await model.previousMonth(env: env, guest: guest) }
            }
            .accessibilityIdentifier("calendar.prev")

            RoundIconButton(symbol: "chevron.right", label: "다음 달", tint: WPColor.gray600) {
                Task { await model.nextMonth(env: env, guest: guest) }
            }
            .accessibilityIdentifier("calendar.next")

            // 웹의 세로 구분선
            Rectangle()
                .fill(WPColor.gray200)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 4)

            RoundIconButton(symbol: "xmark", label: "닫기", tint: WPColor.gray400) {
                dismiss()
            }
            .accessibilityIdentifier("calendar.close")
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .padding(.top, 32)
        .padding(.bottom, 16)
    }

    // MARK: - 격자

    private var grid: some View {
        let cells = model.grid
        let today = KstDate.today()

        return VStack(spacing: 0) {
            ForEach(0..<(CalendarGrid.cellCount / 7), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let date = cells[row * 7 + column]
                        DayCell(
                            date: date,
                            columnIndex: column,
                            inCurrentMonth: model.inCurrentMonth(date),
                            isToday: date == today,
                            plans: model.plans(on: date)
                        ) {
                            selectedDate = date
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

/// `fullScreenCover(item:)` 은 Identifiable 을 요구한다. Int 를 그대로 넘길 수 없어 감싼다.
private struct ScheduleRef: Identifiable, Hashable {
    var id: Int
}

// MARK: - 부품

/// 웹의 `p-2 hover:bg-gray-100 rounded-full` 아이콘 버튼.
private struct RoundIconButton: View {
    var symbol: String
    var label: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 일=빨강, 토=파랑, 나머지 회색 (웹 red-400 / blue-400 / gray-400)
private func weekdayColor(_ index: Int) -> Color {
    switch index {
    case 0: return Color(hex: 0xF87171)
    case 6: return Color(hex: 0x60A5FA)
    default: return WPColor.gray400
    }
}

/// 격자 선. 웹 `border-gray-50`
private let gridLine = WPColor.gray50

private struct WeekdayRow: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(CalendarGrid.weekdayLabels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(WPFont.hak(12, .bold))
                    .foregroundStyle(weekdayColor(index))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .border(gridLine, width: 0.5)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct DayCell: View {
    var date: KstDate
    var columnIndex: Int
    var inCurrentMonth: Bool
    var isToday: Bool
    var plans: [CalendarPlanItem]
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                dayNumber

                Spacer().frame(height: 4)

                // 웹: 최대 2개까지만 보여주고 나머지는 "+N"
                ForEach(plans.prefix(2)) { plan in
                    PlanChip(plan: plan)
                        .padding(.bottom, 2)
                }

                if plans.count > 2 {
                    MoreBadge(count: plans.count - 2)
                }

                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .top)
            // 이번 달이 아닌 칸은 옅은 회색 배경 (웹 `bg-gray-50/50`)
            .background(inCurrentMonth ? Color.clear : gridLine.opacity(0.5))
            .border(gridLine, width: 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar.day.\(date.dateString)")
    }

    private var dayNumber: some View {
        Text(verbatim: "\(date.day)")
            .font(WPFont.hak(12, .bold))
            .foregroundStyle(numberColor)
            .frame(width: 20, height: 20)
            .background {
                // 오늘은 핑크 원 안에 흰 숫자
                if isToday {
                    Circle().fill(WPColor.primary)
                }
            }
    }

    private var numberColor: Color {
        if !inCurrentMonth { return WPColor.gray300 }
        if isToday { return .white }
        if columnIndex == 0 || columnIndex == 6 { return weekdayColor(columnIndex) }
        // 웹 gray-700
        return Color(hex: 0x374151)
    }
}

private struct PlanChip: View {
    var plan: CalendarPlanItem

    var body: some View {
        let done = plan.isCompleted

        // 제목은 사용자 입력값이라 Tmoney (웹 `font-user-content`)
        Text(plan.title)
            .font(WPFont.tmoney(8))
            .strikethrough(done)
            .foregroundStyle(done ? WPColor.gray400 : WPColor.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                // 웹 `bg-gray-100` / `bg-[#ee2b8c10]`
                done ? WPColor.gray100 : WPColor.primary.opacity(Double(0x10) / 255),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
    }
}

private struct MoreBadge: View {
    var count: Int

    var body: some View {
        Text(verbatim: "+\(count)")
            .font(WPFont.hak(10, .black))
            .foregroundStyle(WPColor.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .background(WPColor.primary.opacity(Double(0x0A) / 255), in: Capsule())
            .overlay(Capsule().stroke(WPColor.primary.opacity(Double(0x15) / 255), lineWidth: 1))
            .padding(.top, 2)
    }
}

private struct AddFloatingButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(WPColor.primary, in: Circle())
                // 웹 `shadow-xl shadow-[#ee2b8c44]`
                .shadow(color: WPColor.primary.opacity(Double(0x44) / 255), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("플랜 추가")
        .accessibilityIdentifier("calendar.add")
    }
}

// MARK: - 날짜별 플랜 시트

/// 웹의 "Day Detail Modal" — 아래에서 올라오는 시트.
private struct DayPlansSheet: View {
    var date: KstDate
    var plans: [CalendarPlanItem]
    var readOnly: Bool
    var onClose: () -> Void
    var onOpen: (Int) -> Void
    var onAdd: () -> Void

    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "\(date.year)년 \(date.month)월 \(date.day)일")
                    .font(WPFont.hak(20, .black))
                    .foregroundStyle(WPColor.textPrimary)

                Spacer()

                RoundIconButton(symbol: "xmark", label: "닫기", tint: WPColor.gray400, action: onClose)
            }

            Spacer().frame(height: 24)

            ScrollView {
                VStack(spacing: 12) {
                    if plans.isEmpty {
                        Text("등록된 플랜이 없어요")
                            .font(WPFont.hak(14, .bold))
                            .foregroundStyle(WPColor.gray400)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else {
                        ForEach(plans) { plan in
                            DayPlanRow(plan: plan) { onOpen(plan.id) }
                        }
                    }

                    if !readOnly {
                        DashedAddButton(action: onAdd)
                            .padding(.top, 8)
                    }
                }
            }
            // 내용만큼만 차지하게 고정한다. 자동 높이로 두면 시트 아래가 텅 빈다.
            .frame(height: listHeight)

            Spacer().frame(height: 24)

            Button(action: onClose) {
                Text("확인")
                    .font(WPFont.hak(18, .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(WPColor.textPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("calendar.sheet.confirm")
        }
        .padding(24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.white)
        // 웹은 내용 높이만큼만 올라오는 시트다. 기본 detent 를 쓰면 아래가 비어 보인다.
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
    }

    /// 목록 영역 높이. 웹의 `max-h-[400px]` 과 같은 상한을 둔다.
    private var listHeight: CGFloat {
        // 행 하나 = 카드 72 + 간격 12
        let rows: CGFloat = plans.isEmpty ? 130 : CGFloat(plans.count) * 84
        let addButton: CGFloat = readOnly ? 0 : 72
        return min(rows + addButton, 400)
    }

    /// 시트 전체 높이 — 위아래 여백 + 제목 + 목록 + "확인" 버튼.
    private var sheetHeight: CGFloat {
        listHeight + 196
    }
}

private struct DayPlanRow: View {
    var plan: CalendarPlanItem
    var onTap: () -> Void

    var body: some View {
        let done = plan.isCompleted

        Button(action: onTap) {
            HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(done ? WPColor.gray200 : WPColor.primary.opacity(Double(0x10) / 255))
                    .frame(width: 40, height: 40)

                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(WPColor.gray400)
                } else {
                    Circle()
                        .fill(WPColor.primary)
                        .frame(width: 10, height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(WPFont.tmoney(16, .bold))
                    .strikethrough(done)
                    .foregroundStyle(done ? WPColor.gray400 : WPColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !plan.categoryName.isEmpty {
                    Text(plan.categoryName)
                        .font(WPFont.hak(12, .bold))
                        .foregroundStyle(WPColor.gray400)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(WPColor.gray300)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(WPColor.gray50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DashedAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .heavy))
                Text("플랜 추가하기")
                    .font(WPFont.hak(14, .bold))
            }
            .foregroundStyle(WPColor.gray400)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        WPColor.gray200,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar.sheet.add")
    }
}
