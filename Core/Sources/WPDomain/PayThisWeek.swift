import Foundation
import WPModels
import WPUtils

public enum PayThisWeek {
    /// Android window is inclusive: today through today + 7, ordered by date.
    public static func pick(_ schedules: [ScheduleItem], today: KstDate) -> [(item: ScheduleItem, days: Int)] {
        schedules.enumerated().compactMap { index, item -> (ScheduleItem, Int, Int)? in
            guard !item.isPaid, (item.amount ?? 0) > 0,
                  let raw = item.startDate, let date = KstDate(dateString: raw) else { return nil }
            let days = today.days(until: date)
            guard (0...7).contains(days) else { return nil }
            return (item, days, index)
        }.sorted { $0.1 == $1.1 ? $0.2 < $1.2 : $0.1 < $1.1 }.map { ($0.0, $0.1) }
    }
    public static func reminderText(_ setting: ReminderSetting) -> String {
        guard !setting.leadDays.isEmpty else { return "알림 시점을 고르지 않았어요" }
        let days = Set(setting.leadDays).sorted(by: >).map { $0 == 0 ? "당일" : $0 == 1 ? "하루 전" : "\($0)일 전" }.joined(separator: " · ")
        let hour = setting.hour
        return "\(days) \(ReminderRules.hourLabel(hour))"
    }
}
