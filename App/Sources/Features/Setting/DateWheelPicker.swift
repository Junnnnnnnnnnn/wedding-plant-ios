import SwiftUI
import WPUtils

/// 웹 `app/components/DatePickerWheel.tsx` 이식.
///
/// 연속 스크롤 휠 하나가 아니라 **년/월/일 3개의 독립 카드**이고, 각 카드 위아래에 셰브론이 붙는다.
///
/// - Note: 가운데 선택 밴드는 iOS 기본 `Picker(.wheel)` 이 그리는 것을 쓴다.
///   안드로이드는 stone-300 가로선 2줄을 직접 그렸지만, 여기서 스크롤·스냅을 손으로 만들면
///   깨질 여지가 크고 iOS 사용자에게는 시스템 휠이 더 자연스럽다.
///   3열 구성·라벨·셰브론·연도 범위 같은 구조는 웹과 동일하게 맞췄다.
struct DateWheelPicker: View {
    @Binding var value: KstDate

    /// 선택 가능한 하한. `nil` 이면 제한 없음.
    ///
    /// 온보딩에서는 결혼식이 **과거일 수 없으므로** 오늘을 넘긴다.
    /// 반대로 프로필 수정에서는 이미 지난 결혼일도 정상이라 하한을 두지 않는다.
    var minDate: KstDate?

    /// 웹과 동일: 올해부터 100년. 하한이 있으면 그 해부터.
    private var years: [Int] {
        let start = minDate?.year ?? KstDate.today().year
        return Array(start...(start + 99))
    }

    private var months: [Int] {
        guard let minDate, value.year == minDate.year else { return Array(1...12) }
        return Array(minDate.month...12)
    }

    private var days: [Int] {
        let last = KstDate.daysInMonth(year: value.year, month: value.month)
        guard let minDate, value.year == minDate.year, value.month == minDate.month else {
            return Array(1...last)
        }
        return Array(min(minDate.day, last)...last)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            WheelColumn(
                label: "년",
                width: 88,
                items: years,
                selection: Binding(
                    get: { value.year },
                    set: { apply(year: $0) }
                ),
                // 년은 순환하지 않는다 (웹도 clamp)
                onStep: { direction in
                    guard let index = years.firstIndex(of: value.year) else { return }
                    let next = min(max(index + direction, 0), years.count - 1)
                    apply(year: years[next])
                }
            )

            WheelColumn(
                label: "월",
                width: 68,
                items: months,
                selection: Binding(
                    get: { value.month },
                    set: { apply(month: $0) }
                ),
                // 월은 순환한다 (웹 handleMonthClick 의 modulo).
                // 하한 때문에 목록이 짧아질 수 있으므로 값이 아니라 **인덱스**로 순환한다.
                onStep: { direction in
                    let list = months
                    guard let index = list.firstIndex(of: value.month), !list.isEmpty else { return }
                    let next = ((index + direction) + list.count) % list.count
                    apply(month: list[next])
                }
            )

            WheelColumn(
                label: "일",
                width: 68,
                items: days,
                selection: Binding(
                    get: { value.day },
                    set: { apply(day: $0) }
                ),
                onStep: { direction in
                    let list = days
                    guard let index = list.firstIndex(of: value.day), !list.isEmpty else { return }
                    let next = ((index + direction) + list.count) % list.count
                    apply(day: list[next])
                }
            )
        }
    }

    /// 월/년이 바뀌어 해당 월의 일수를 넘으면 마지막 날로 보정한다 (웹과 동일).
    private func apply(year: Int? = nil, month: Int? = nil, day: Int? = nil) {
        let y = year ?? value.year
        let m = month ?? value.month
        let maxDay = KstDate.daysInMonth(year: y, month: m)
        let d = min(day ?? value.day, maxDay)
        guard var next = KstDate(year: y, month: m, day: d) else { return }
        // 하한 아래로 내려가면 하한으로 끌어올린다.
        if let minDate, next < minDate { next = minDate }
        value = next
    }
}

private struct WheelColumn: View {
    var label: String
    var width: CGFloat
    var items: [Int]
    @Binding var selection: Int
    var onStep: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(WPFont.hak(12))
                .foregroundStyle(WPColor.stone500)

            chevron("chevron.up") { onStep(-1) }

            Picker(label, selection: $selection) {
                ForEach(items, id: \.self) { item in
                    // verbatim 필수. `Text("\(item)")` 는 LocalizedStringKey 로 해석돼
                    // 로케일 숫자 포맷이 붙는다 → 연도가 "2,026" 으로 나온다.
                    Text(verbatim: "\(item)")
                        .font(WPFont.tmoney(18, .semibold))
                        .foregroundStyle(WPColor.stone900)
                        .tag(item)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: width, height: 160)
            .clipped()
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(WPColor.stone200, lineWidth: 2)
            )

            chevron("chevron.down") { onStep(1) }
        }
    }

    private func chevron(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WPColor.stone400)
                .frame(width: width, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
