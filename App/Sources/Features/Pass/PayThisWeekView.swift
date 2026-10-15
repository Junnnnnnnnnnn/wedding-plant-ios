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
            PayThisWeekBody(
                items: items, hasPass: pass?.hasPass,
                reminderText: PayThisWeek.reminderText(pass?.hasPass == true ? reminder : ReminderSetting()),
                showReminder: showReminder, dateLabel: dateLabel, onSelect: onSelect,
                onReminder: { if pass?.hasPass == true { showSettings = true } else { showPass = true } }
            )
            .padding(.horizontal, 16).padding(.top, 16)
            .task(id: roomId) { await load() }
            .fullScreenCover(isPresented: $showSettings, onDismiss: { Task { await load() } }) { ReminderSettingsView(roomId: roomId) }
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

/// 띠의 **모양만** — 안드로이드 `PayThisWeekBody`(웹 `PayThisWeekStrip` `variant="phone"`).
/// `rounded-[22px] border-[#ee2b8c0f] bg-white p-4 shadow-sm`, **무지개 테두리는 잠금 줄에만**.
/// - hasPass: nil 이면 받는 중 — 알림 줄을 미룬다(산 사람에게 자물쇠가 한 번 번쩍이지 않게).
struct PayThisWeekBody: View {
    let items: [(item: ScheduleItem, days: Int)]
    var hasPass: Bool?
    var reminderText: String
    var showReminder = true
    var dateLabel: (String?) -> String
    var onSelect: (Int) -> Void = { _ in }
    var onReminder: () -> Void = {}

    private static let ink400 = Color(hex: 0x9AA0A6)
    private static let brand700 = Color(hex: 0xCC1873)
    private static let pinkWash = Color(hex: 0xFFF7FB)
    private static let muted = Color(hex: 0x7A6C74)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                (Text("이번 주 결제할 것 ") + Text("\(items.count)").foregroundColor(Self.ink400))
                    .tracking(-0.35).wpTypography(14, .bold).foregroundStyle(WPColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                WPTmoneyText(text: "\(withThousands(items.reduce(0) { $0 + ($1.item.amount ?? 0) }))만 원", size: 15, bold: true,
                             color: UIColor(Self.brand700))
                    .fixedSize()
            }
            VStack(spacing: 6) {
                ForEach(items, id: \.item.id) { entry in
                    Button { onSelect(entry.item.id) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.item.title).wpTypography(13.5, .bold, lineHeight: 20).foregroundStyle(WPColor.textPrimary).lineLimit(1)
                                Text([entry.item.categoryName.isEmpty ? nil : entry.item.categoryName, dateLabel(entry.item.startDate).isEmpty ? nil : dateLabel(entry.item.startDate)]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .wpTypography(11.5, lineHeight: 17).foregroundStyle(Self.ink400).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .trailing, spacing: 2) {
                                WPTmoneyText(text: "\(withThousands(entry.item.amount ?? 0))만 원", size: 13.5, bold: true,
                                             color: UIColor(WPColor.textPrimary), lineHeight: 20)
                                    .fixedSize()
                                Text(entry.days == 0 ? "오늘" : "D-\(entry.days)").wpTypography(11, .bold, lineHeight: 16).foregroundStyle(WPColor.primary)
                            }
                        }
                        .padding(8).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("payment.\(entry.item.id)")
                }
            }
            .padding(.top, 12)
            if showReminder, let hasPass {
                Button(action: onReminder) {
                    if hasPass {
                        // 누르면 결제일 알림 설정으로 간다 — 어디로 오는지는 그 화면이 말한다
                        HStack(spacing: 0) {
                            WPLucideIcon(paths: WPIconPaths.bell, size: 16, color: WPColor.primary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("준비 패스 · 결제일 알림").wpTypography(12, .bold, lineHeight: 16).foregroundStyle(Self.brand700)
                                Text(reminderText).wpTypography(11, lineHeight: 18).foregroundStyle(Self.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
                            Text("설정").wpTypography(11, .bold).foregroundStyle(Self.brand700)
                            WPLucideIcon(paths: WPIconPaths.chevronRight, size: 14, color: Self.brand700)
                        }
                        .padding(12)
                        .background(Self.pinkWash, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        HStack(spacing: 0) {
                            WPLucideIcon(paths: WPIconPaths.bell, size: 18, color: WPColor.primary)
                                .frame(width: 36, height: 36).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    WPLucideIcon(paths: WPIconPaths.lock, size: 10, color: Self.brand700)
                                    Text("준비 패스 전용").wpTypography(10, .bold, lineHeight: 14).foregroundStyle(Self.brand700)
                                }
                                Text("결제일 전에 알림 받기").wpTypography(13, .bold, lineHeight: 18).foregroundStyle(WPColor.textPrimary)
                                Text("7일 전 · 하루 전 · 당일 오전 9시").wpTypography(11, lineHeight: 18).foregroundStyle(Self.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
                            WPLucideIcon(paths: WPIconPaths.chevronRight, size: 16, color: Self.brand700).padding(.leading, 12)
                        }
                        .padding(12)
                        .background(Self.pinkWash, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xF4DCE8), lineWidth: 1))
                        .overlay { PassHighlightBorder(radius: 16) }
                    }
                }
                .buttonStyle(.plain).accessibilityIdentifier("payment.reminders")
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(WPColor.primary.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}
