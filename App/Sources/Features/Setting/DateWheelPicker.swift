import SwiftUI
import WPUtils

/// 웹 DatePickerWheel 의 치수 — `h-40`(160) 상자 안에서 `h-12`(48) 한 칸이 가운데 밴드
private let wheelBoxHeight: CGFloat = 160
private let wheelItemHeight: CGFloat = 48
private let wheelEdgePad: CGFloat = (wheelBoxHeight - wheelItemHeight) / 2 // 56

/// 웹 `app/components/DatePickerWheel.tsx` 이식 — 안드로이드 `ui/setting/DateWheelPicker.kt` 와 같은 모양.
///
/// 연속 스크롤 휠 하나가 아니라 **년/월/일 3개의 독립 칸**이다(시안 C안 10 — 회색 채움 상자,
/// 고른 칸은 흰 면 + 분홍 실선). 값을 굴리거나 **눌러서** 고른다.
///
/// 예전에는 시스템 `Picker(.wheel)` 위아래에 셰브론을 붙였는데, 안드로이드는 시안에서 화살표를 걷었고
/// 시스템 휠의 회색 밴드·3D 곡면이 안드로이드와 전혀 다르게 보였다.
struct DateWheelPicker: View {
    @Binding var value: KstDate

    /// 고를 수 있는 가장 이른 날짜. `nil` 이면 제한 없음.
    ///
    /// 온보딩(결혼식 날짜 정하기)은 **올해 1월 1일**이 하한이다 — 연도는 올해부터지만 올해의 지난
    /// 날짜는 고를 수 있다(웹 d513e95, 안드로이드와 같음). 프로필·플랜 날짜는 하한이 없다.
    var minDate: KstDate?

    /// 웹과 동일: 하한 연도부터 100년. 하한이 없으면 50년 전부터(안드로이드와 같음 — 지난 일정의 날짜도 보여야 한다).
    private var years: [Int] {
        let first = minDate?.year ?? (KstDate.today().year - 50)
        return Array(first...(first + 99))
    }

    private var days: [Int] { Array(1...KstDate.daysInMonth(year: value.year, month: value.month)) }

    var body: some View {
        // 웹 `w-full max-w-[340px] grid grid-cols-3 gap-3`
        HStack(alignment: .top, spacing: 12) {
            DateWheelColumn(label: "년", items: years, selected: value.year) { apply(year: $0) }
            DateWheelColumn(label: "월", items: Array(1...12), selected: value.month) { apply(month: $0) }
            DateWheelColumn(label: "일", items: days, selected: value.day) { apply(day: $0) }
        }
        .frame(maxWidth: 340)
    }

    /// 월/년이 바뀌어 해당 월의 일수를 넘으면 마지막 날로 보정한다 (웹과 동일).
    private func apply(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        let y = year ?? value.year
        let m = month ?? value.month
        let d = min(day ?? value.day, KstDate.daysInMonth(year: y, month: m))
        guard var next = KstDate(year: y, month: m, day: d) else { return }
        // 하한보다 이르면 하한으로 되돌린다.
        if let minDate, next < minDate { next = minDate }
        if next != value { value = next }
    }
}

/// 한 칸(년·월·일). 시안(C안 10) — **위아래 화살표가 없다.** 값 자체를 눌러 고르고, 굴려도 된다.
private struct DateWheelColumn: View {
    var label: String
    var items: [Int]
    var selected: Int
    var onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            // 웹 `mb-2 text-center text-[12px] font-bold text-[#868b94]`
            Text(label)
                .wpTypography(12, .bold)
                .foregroundStyle(WPColor.fgSubtle)
            DateWheelBox(items: items, selected: selected, onSelect: onSelect)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DateWheelBox: View {
    var items: [Int]
    var selected: Int
    var onSelect: (Int) -> Void

    /// 가운데 밴드에 선 칸. 스크롤이 멈추면 이 값이 고른 값이 된다.
    @State private var centered: Int?

    var body: some View {
        ZStack {
            // 웹 `relative h-40 w-full overflow-hidden rounded-xl bg-[#f7f8f9]`
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(WPColor.fill)
            // 고른 칸 — 흰 면 + 분홍 실선 한 겹(시안 `.wv--on`). 숫자 **아래**에 깔린다.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(WPColor.brand300, lineWidth: 1))
                .frame(height: wheelItemHeight)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        let on = item == selected
                        // verbatim 필수. `Text("\(item)")` 는 로케일 숫자 포맷이 붙어 연도가 "2,026" 이 된다.
                        Text(verbatim: "\(item)")
                            .font(WPFont.hak(on ? 20 : 16, on ? .bold : .regular))
                            .foregroundStyle(on ? WPColor.fgNeutral : WPColor.buttonDisabledText)
                            .frame(maxWidth: .infinity)
                            .frame(height: wheelItemHeight)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(item) }
                    }
                }
                .scrollTargetLayout()
            }
            // 위아래 56 을 비워야 첫/마지막 항목도 가운데 밴드에 온다
            .contentMargins(.vertical, wheelEdgePad, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centered, anchor: .center)
        }
        .frame(height: wheelBoxHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { centered = selected }
        // 손으로 굴려 가운데 칸이 바뀌면 고른다(안드로이드는 멈췄을 때 — 여기서는 칸에 붙을 때마다 바뀐다).
        .onChange(of: centered) { _, now in
            if let now, now != selected { onSelect(now) }
        }
        // 값을 눌렀거나 월이 바뀌어 값이 달라지면 휠도 따라 이동
        .onChange(of: selected) { _, now in
            if centered != now { withAnimation(.easeOut(duration: 0.25)) { centered = now } }
        }
        .onChange(of: items) { _, _ in
            if centered != selected { centered = selected }
        }
        // 안드로이드 `haptics.tick()` — 굴릴 때 칸마다
        .sensoryFeedback(.selection, trigger: centered)
    }
}
