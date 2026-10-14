import SwiftUI
import WPModels
import WPUtils

struct InvitationCalendar: View {
    let content: InvitationContent
    let palette: InvitationPalette
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
    var body: some View {
        VStack(spacing: 16) {
            Text("SAVE OUR DAY").wpTypography(9, face: .kakao, lineHeight: 13.5).tracking(3).foregroundStyle(palette.muted)
            if let date = content.weddingDate.flatMap({ KstDate(dateString: $0) }) {
                let weekday = KST.calendar.component(.weekday, from: date.startOfDay) - 1
                VStack(spacing: 6) {
                    Text(verbatim: "\(date.year)년 \(date.month)월 \(date.day)일 \(weekdays[weekday])요일").wpTypography(19, face: .kakao, lineHeight: 28.5).tracking(-0.5)
                    if let time = timeLabel { Text(time).wpTypography(13, face: .kakao, lineHeight: 19.5).foregroundStyle(palette.muted) }
                }
                Color.clear.frame(height: 0)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(0..<7) { i in Text(weekdays[i]).wpTypography(10, face: .kakao, lineHeight: 15).foregroundStyle(i == 0 ? palette.gold : palette.muted).frame(maxWidth: .infinity) }
                    }.padding(.bottom, 10)
                    palette.rule.frame(height: 1)
                    let first = KstDate(year: date.year, month: date.month, day: 1)!
                    let lead = KST.calendar.component(.weekday, from: first.startOfDay) - 1
                    let days = KST.calendar.range(of: .day, in: .month, for: date.startOfDay)!.count
                    let count = ((lead + days + 6) / 7) * 7
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                        ForEach(0..<count, id: \.self) { index in
                            let day = index - lead + 1
                            ZStack {
                                if (1...days).contains(day) {
                                    if day == date.day { Circle().fill(palette.forest).frame(width: 32, height: 32) }
                                    Text("\(day)").font(.custom(day == date.day ? "KakaoSmallSans-Bold" : "KakaoSmallSans-Regular", size: 12)).foregroundStyle(day == date.day ? palette.paper : index % 7 == 0 ? palette.gold : palette.ink)
                                }
                            }.frame(height: 38)
                        }
                    }
                }.frame(maxWidth: 320)
                let days = date.daysFromToday()
                Text(days > 0 ? "결혼식까지 \(days)일 남았어요" : days == 0 ? "오늘, 두 사람이 결혼해요" : "\(-days)일 전, 두 사람이 부부가 되었어요").wpTypography(12, face: .kakao, lineHeight: 18).foregroundStyle(palette.forest)
            } else {
                Text("예식 날짜를 정하면 달력이 펼쳐져요").wpTypography(11, face: .kakao, lineHeight: 16.5).padding(12).background(palette.placeholder)
            }
        }.frame(maxWidth: .infinity).padding(.horizontal, 28).padding(.top, 56).padding(.bottom, 48)
    }
    private var timeLabel: String? {
        guard let raw = content.weddingTime else { return nil }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        let h = parts[0] % 12 == 0 ? 12 : parts[0] % 12
        return "\(parts[0] < 12 ? "오전" : "오후") \(h)시" + (parts[1] == 0 ? "" : " \(parts[1])분")
    }
}
