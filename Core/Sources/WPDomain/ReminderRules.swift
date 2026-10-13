import WPModels
import WPUtils

/// Android ReminderRules: reminder times are KST and apply to every unpaid payment.
public enum ReminderRules {
    public static func leadLabel(_ day: Int) -> String { day == 0 ? "당일" : day == 1 ? "하루 전" : "\(day)일 전" }
    public static func hourLabel(_ hour: Int) -> String {
        hour == 12 ? "낮 12시" : hour < 12 ? "오전 \(hour)시" : "오후 \(hour - 12)시"
    }
    public static func nextAlertLabel(payDay: KstDate, setting: ReminderSetting, today: KstDate, nowHour: Int) -> String {
        if payDay < today { return "날짜가 지났어요 · 결제 여부 확인" }
        if setting.leadDays.isEmpty { return "알림 없음" }
        guard let next = setting.leadDays.sorted(by: >).map({ payDay.adding(days: -$0) })
            .first(where: { $0 > today || ($0 == today && nowHour < setting.hour) }) else { return "남은 알림 없음" }
        let date = next == today ? "오늘" : "\(next.month)월 \(next.day)일"
        return "다음 알림 \(date) \(hourLabel(setting.hour))"
    }
    public static func payments(_ items: [ScheduleItem]) -> [ScheduleItem] {
        CalendarExport.sorted(items).filter { !$0.isPaid && ($0.amount ?? 0) > 0 && CalendarExport.dateOf($0) != nil }
    }
}
