import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

struct PayThisWeekView: View {
    let schedules: [ScheduleItem]
    let today: KstDate
    let roomId: Int?
    let showReminder: Bool
    var onSelect: (Int) -> Void
    @EnvironmentObject private var env: AppEnvironment
    @State private var pass: PassState?
    @State private var reminder = ReminderSetting()
    @State private var showPass = false
    @State private var showSettings = false
    private var items: [(item: ScheduleItem, days: Int)] { PayThisWeek.pick(schedules, today: today) }
    var body: some View {
        if !items.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    (Text("이번 주 결제할 것 ") + Text("\(items.count)").foregroundColor(Color(hex: 0x9AA0A6)))
                        .font(WPFont.hak(14, .bold)).tracking(-0.35)
                    Spacer(minLength: 12)
                    Text("\(withThousands(items.reduce(0) { $0 + ($1.item.amount ?? 0) }))만 원")
                        .font(WPFont.tmoney(15, .heavy)).foregroundStyle(Color(hex: 0xCC1873))
                }
                VStack(spacing: 6) {
                    ForEach(items, id: \.item.id) { entry in
                        Button { onSelect(entry.item.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.item.title).font(WPFont.hak(13.5, .bold)).lineLimit(1)
                                    Text("\(entry.item.categoryName) · \(dateLabel(entry.item.startDate))")
                                        .font(WPFont.hak(11.5)).foregroundStyle(Color(hex: 0x9AA0A6)).lineLimit(1)
                                }
                                Spacer(minLength: 12)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(withThousands(entry.item.amount ?? 0))만 원").font(WPFont.tmoney(13.5, .heavy))
                                    Text(entry.days == 0 ? "오늘" : "D-\(entry.days)").font(WPFont.hak(11, .bold)).foregroundStyle(WPColor.primary)
                                }
                            }.padding(8).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("payment.\(entry.item.id)")
                    }
                }
                if showReminder, let pass {
                    Button { if pass.hasPass { showSettings = true } else { showPass = true } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell").font(.system(size: 18)).foregroundStyle(WPColor.primary)
                            VStack(alignment: .leading, spacing: 4) {
                                if !pass.hasPass { Label("준비 패스 전용", systemImage: "lock").font(WPFont.hak(10, .bold)) }
                                Text(pass.hasPass ? "준비 패스 · 결제일 알림" : "결제일 전에 알림 받기").font(WPFont.hak(12, .bold))
                                Text(PayThisWeek.reminderText(pass.hasPass ? reminder : ReminderSetting())).font(WPFont.hak(11)).foregroundStyle(Color(hex: 0x7A6C74))
                            }
                            Spacer(minLength: 0)
                            if pass.hasPass { Text("설정").font(WPFont.hak(11, .bold)) }
                            Image(systemName: "chevron.right").font(.system(size: 14))
                        }.foregroundStyle(Color(hex: 0xCC1873)).padding(12)
                            .background(Color(hex: 0xFFF7FB), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xF4DCE8), lineWidth: pass.hasPass ? 0 : 1))
                    }.buttonStyle(.plain).accessibilityIdentifier("payment.reminders")
                }
            }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(WPColor.primary.opacity(0.06)))
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                .padding(.horizontal, 16).padding(.top, 16)
                .task(id: roomId) { await load() }
                .sheet(isPresented: $showSettings, onDismiss: { Task { await load() } }) { ReminderSettingsView() }
                .fullScreenCover(isPresented: $showPass, onDismiss: { Task { await load() } }) { PassView(roomId: roomId) }
        }
    }
    private func dateLabel(_ raw: String?) -> String {
        guard let raw, let date = KstDate(dateString: raw) else { return "" }
        return "\(date.month)월 \(date.day)일"
    }
    private func load() async {
        guard showReminder, let roomId else { return }
        pass = try? await env.api.send(Endpoint.pass(roomId: roomId))
        if pass?.hasPass == true, let setting: ReminderSetting = try? await env.api.send(Endpoint.reminderSetting()) { reminder = setting }
    }
}
