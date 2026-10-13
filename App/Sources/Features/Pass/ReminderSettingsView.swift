import SwiftUI
import UserNotifications
import WPDomain
import WPModels
import WPNetworking
import WPUtils

@MainActor final class ReminderSettingsModel: ObservableObject {
    @Published var setting: ReminderSetting?
    @Published var payments: [ScheduleItem]?
    @Published var hasPass: Bool?
    @Published var saving = false
    @Published var saved = false
    @Published var error: String?
    @Published var saveError: String?

    func load(_ env: AppEnvironment, roomId: Int?) async {
        error = nil
        do { setting = try await env.api.send(Endpoint.reminderSetting()) }
        catch { self.error = error.localizedDescription }
        do {
            var room = roomId ?? env.boundRoomId
            if room == nil { let user: PlanUser = try await env.api.send(Endpoint.user()); room = user.roomId }
            guard let room else { payments = []; return }
            let pass: PassState = try await env.api.send(Endpoint.pass(roomId: room)); hasPass = pass.hasPass
            var pages = SchedulePages(), page = 1
            while !Task.isCancelled {
                let result: SchedulePage = try await env.api.send(Endpoint.allSchedules(roomId: room, page: page))
                if try pages.append(result) { break }; page += 1
            }
            try Task.checkCancellation()
            payments = ReminderRules.payments(pages.result)
        } catch { self.error = error.localizedDescription }
    }
    /// Apply immediately; serialize edits and restore the last confirmed value on failure.
    func save(_ next: ReminderSetting, api: APIClient) async {
        guard let before = setting, !saving else { return }
        setting = next; saving = true; saved = false; saveError = nil
        defer { saving = false }
        do { setting = try await api.send(Endpoint.saveReminder(leadDays: next.leadDays, hour: next.hour, email: next.email)); saved = true }
        catch { setting = before; saveError = error.localizedDescription }
    }
}

struct ReminderSettingsView: View {
    var roomId: Int? = nil
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = ReminderSettingsModel()
    @State private var permitted = false
    @State private var showPass = false
    @State private var schedule: Int?
    var body: some View {
        NavigationStack {
            ReminderSettingsBody(setting: model.setting, payments: model.payments,
                showPassBanner: model.hasPass == false, phonePermitted: permitted,
                today: .today(), nowHour: KST.calendar.component(.hour, from: Date()),
                saving: model.saving, saved: model.saved, error: model.error, saveError: model.saveError,
                onBack: { dismiss() }, onPhoneSettings: {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                }, onChange: { next in Task { await model.save(next, api: env.api) } },
                onRetry: { Task { await model.load(env, roomId: roomId) } },
                onOpenSchedule: { schedule = $0 }, onOpenPass: { showPass = true })
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: Binding(get: { schedule != nil }, set: { if !$0 { schedule = nil } })) {
                    if let schedule { ScheduleDetailView(scheduleId: schedule, roomId: roomId ?? env.boundRoomId) }
                }
        }
        .task { await permission(); await model.load(env, roomId: roomId) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await permission() } } }
        .fullScreenCover(isPresented: $showPass, onDismiss: { Task { await model.load(env, roomId: roomId) } }) { PassView(roomId: roomId) }
    }
    private func permission() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        permitted = [.authorized, .provisional, .ephemeral].contains(status)
    }
}

/// Same state and layout as Android ReminderSettingsBody; also rendered by the paired screenshot test.
struct ReminderSettingsBody: View {
    var setting: ReminderSetting?
    var payments: [ScheduleItem]?
    var showPassBanner: Bool
    var phonePermitted: Bool
    var today: KstDate
    var nowHour: Int
    var saving = false
    var saved = false
    var error: String? = nil
    var saveError: String? = nil
    var onBack: () -> Void = {}
    var onPhoneSettings: () -> Void = {}
    var onChange: (ReminderSetting) -> Void = { _ in }
    var onRetry: () -> Void = {}
    var onOpenSchedule: (Int) -> Void = { _ in }
    var onOpenPass: () -> Void = {}
    private var shown: ReminderSetting { setting ?? ReminderSetting() }
    private let warning = Color(hex: 0xB45309)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 0) {
                    if showPassBanner {
                        Button(action: onOpenPass) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("준비 패스가 있어야 알림이 가요").wpTypography(13, .bold)
                                    Text("설정은 지금 해 두면 패스를 켜는 날부터 그대로 써요").wpTypography(11.5, lineHeight: 17).foregroundStyle(WPColor.fgSubtle)
                                }
                                Spacer(minLength: 8); WPMaterialIcon(kind: .right).frame(width: 18, height: 18).foregroundStyle(WPColor.gray300)
                            }.padding(14).background(WPColor.brand100, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.brand200))
                        }.buttonStyle(.plain).padding(.bottom, 20)
                    }
                    if let error {
                        HStack { Text(error); Spacer(); Button("다시 시도", action: onRetry) }
                            .wpTypography(13).foregroundStyle(WPColor.danger).padding(14)
                            .background(WPColor.dangerBg, in: RoundedRectangle(cornerRadius: 16)).padding(.bottom, 20)
                    }
                    title("받는 곳")
                    card {
                        receiver(.phone, "이 휴대폰", phonePermitted ? "앱이 꺼져 있어도 알림이 와요" : "알림 권한이 꺼져 있어 오지 않아요", color: phonePermitted ? WPColor.fgSubtle : warning) {
                            if phonePermitted { pill("받는 중", color: WPColor.positive, fill: WPColor.positiveWeak) }
                            else { Button("허용하기", action: onPhoneSettings).wpTypography(12, .bold).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8).background(WPColor.primary, in: RoundedRectangle(cornerRadius: 10)) }
                        }
                        divider
                        receiver(.computer, "웹 화면", "웹을 켜 둔 동안 화면 위에 떠요 · 닫혀 있으면 받지 못해요") { pill("켜 둘 때만", color: WPColor.fgMuted, fill: .white) }
                        divider
                        receiver(.email, "이메일", setting == nil ? " " : shown.emailAddress ?? "이메일·구글·애플로 로그인한 계정만 받을 수 있어요") {
                            Toggle("이메일로도 받기", isOn: Binding(get: { shown.email }, set: { value in var next = shown; next.email = value; onChange(next) }))
                                .toggleStyle(ReminderSwitchStyle()).disabled(setting == nil || shown.emailAddress == nil || saving)
                        }
                    }
                    title("언제 알릴까요", hint: "여러 개 고를 수 있어요").padding(.top, 24)
                    card {
                        ViewThatFits(in: .horizontal) {
                            leadRow([7, 3, 1, 0])
                            VStack(alignment: .leading, spacing: 8) { leadRow([7, 3]); leadRow([1, 0]) }
                        }
                        if setting != nil && shown.leadDays.isEmpty {
                            Text("고른 시점이 없어 알림이 가지 않아요").wpTypography(12, .bold).foregroundStyle(warning).padding(.top, 10)
                        }
                        divider
                        HStack {
                            Text("알림 시각").wpTypography(14, .bold); Spacer()
                            Menu {
                                ForEach(7...22, id: \.self) { hour in
                                    Button(ReminderRules.hourLabel(hour)) { var next = shown; next.hour = hour; onChange(next) }
                                }
                            } label: {
                                HStack(spacing: 0) { Text(ReminderRules.hourLabel(shown.hour)).wpTypography(13, .bold); WPMaterialIcon(kind: .down).frame(width: 18, height: 18) }
                                    .foregroundStyle(WPColor.fgMuted).padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 8)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(WPColor.strokeWeak))
                            }.disabled(setting == nil || saving).accessibilityIdentifier("reminder.hour")
                        }
                    }
                    Group {
                        if let saveError { Text(saveError).wpTypography(11.5).foregroundStyle(WPColor.danger) }
                        else if saving { Text("저장하는 중…").wpTypography(11.5).foregroundStyle(WPColor.fgSubtle) }
                        else if saved { Text("저장했어요 · \(PayThisWeek.reminderText(shown))").wpTypography(11.5).foregroundStyle(WPColor.positive) }
                        else { Color.clear.frame(height: 10) }
                    }.padding(.horizontal, 4).padding(.vertical, 6).frame(minHeight: 22, alignment: .leading).accessibilityIdentifier("reminder.saveStatus")
                    title("알림 받을 결제", hint: "모든 결제에 똑같이 적용돼요").padding(.top, 10)
                    paymentList
                    Text("결제를 마친 일정은 알림이 오지 않아요.\n금액·날짜는 각 플랜에서 고칠 수 있어요.")
                        .wpTypography(11.5, lineHeight: 18).foregroundStyle(WPColor.fgSubtle).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.top, 16)
                }.padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 40)
            }
        }.scrollIndicators(.hidden).background(.white).foregroundStyle(WPColor.fgNeutral)
            .ignoresSafeArea(edges: .top).accessibilityIdentifier("reminder.scroll")
    }
    private var header: some View {
        let week = PayThisWeek.pick(payments ?? [], today: today)
        return BrandHead(bottom: 28) {
            HStack(spacing: 0) { Button(action: onBack) { WPMaterialIcon(kind: .left).frame(width: 26, height: 26).frame(width: 36, height: 36) }.buttonStyle(.plain).accessibilityLabel("뒤로가기").accessibilityIdentifier("reminder.back"); Text("결제일 알림").wpTypography(17, .bold) }
            Spacer().frame(height: 14)
            if payments == nil { SkeletonBox(width: 220, height: 82, onBrand: true) }
            else if !week.isEmpty {
                Text("이번 주 결제할 것 \(week.count)건").wpTypography(13).foregroundStyle(.white.opacity(0.85))
                Spacer().frame(height: 4)
                Text("\(withThousands(week.reduce(0) { $0 + ($1.item.amount ?? 0) }))만 원,\n놓치지 않게 알려 드릴게요")
                    .wpTypography(25, .bold, lineHeight: 33).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("결제일이 다가오면\n먼저 알려 드릴게요").wpTypography(23, .bold, lineHeight: 31).fixedSize(horizontal: false, vertical: true)
            }
        }.foregroundStyle(.white)
    }
    private func title(_ text: String, hint: String? = nil) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(text).wpTypography(13, .bold).foregroundStyle(WPColor.fgSubtle); Spacer(minLength: 4)
            if let hint { Text(hint).wpTypography(11.5).foregroundStyle(WPColor.gray400) }
        }.padding(.horizontal, 2).padding(.bottom, 10)
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content).frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).background(WPColor.fill, in: RoundedRectangle(cornerRadius: 18))
    }
    private var divider: some View { Rectangle().fill(WPColor.strokeSubtle).frame(height: 1).padding(.vertical, 12) }
    private func pill(_ text: String, color: Color, fill: Color) -> some View {
        Text(text).wpTypography(11, .bold).foregroundStyle(color).fixedSize().padding(.horizontal, 8).padding(.vertical, 3).background(fill, in: Capsule())
    }
    private func receiver<T: View>(_ icon: WPMaterialIcon.Kind, _ name: String, _ sub: String, color: Color = WPColor.fgSubtle, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 0) {
            WPMaterialIcon(kind: icon).frame(width: 18, height: 18).foregroundStyle(WPColor.primary).frame(width: 34, height: 34).background(.white, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).wpTypography(14, .bold)
                WPParagraph(text: sub, size: 12, lineHeight: 16, color: UIColor(color)).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12).padding(.trailing, 8)
            trailing()
        }
    }
    private func leadRow(_ days: [Int]) -> some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                let on = shown.leadDays.contains(day)
                Button {
                    var next = shown
                    next.leadDays = on ? next.leadDays.filter { $0 != day } : (next.leadDays + [day]).sorted(by: >)
                    onChange(next)
                } label: {
                    HStack(spacing: 4) { if on { WPMaterialIcon(kind: .check).frame(width: 14, height: 14) }; Text(ReminderRules.leadLabel(day)).wpTypography(13, .bold) }
                        .fixedSize().padding(.horizontal, 14).padding(.vertical, 8)
                        .foregroundStyle(on ? .white : WPColor.fgMuted).background(on ? WPColor.primary : .white, in: Capsule())
                        .overlay(Capsule().stroke(on ? WPColor.primary : WPColor.strokeWeak))
                }.buttonStyle(.plain).disabled(setting == nil || saving)
                    .accessibilityIdentifier("reminder.lead.\(day)").accessibilityLabel(ReminderRules.leadLabel(day)).accessibilityValue(on ? "선택됨" : "선택 안 됨")
                    .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
    @ViewBuilder private var paymentList: some View {
        if let payments {
            if payments.isEmpty {
                VStack(spacing: 0) {
                    WPMaterialIcon(kind: .bell).frame(width: 20, height: 20).foregroundStyle(WPColor.gray300).padding(.bottom, 8)
                    Text("아직 결제할 일정이 없어요").wpTypography(13, .bold)
                    Text("플랜에 금액과 날짜를 넣으면 여기에 보여요").wpTypography(12).foregroundStyle(WPColor.fgSubtle)
                }.frame(maxWidth: .infinity).padding(.vertical, 24).background(WPColor.fill, in: RoundedRectangle(cornerRadius: 18))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(payments.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Rectangle().fill(WPColor.strokeSubtle).frame(height: 1) }
                        if let date = CalendarExport.dateOf(item) {
                            Button { onOpenSchedule(item.id) } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).wpTypography(14, .bold).lineLimit(1)
                                        Text("\(date.month)월 \(date.day)일 · \(ReminderRules.nextAlertLabel(payDay: date, setting: shown, today: today, nowHour: nowHour))")
                                            .wpTypography(12).foregroundStyle(date < today ? warning : WPColor.fgSubtle).lineLimit(1)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    HStack(spacing: 0) {
                                        WPTmoneyText(text: "\(withThousands(item.amount ?? 0))만", size: 15, bold: true, color: UIColor(WPColor.fgNeutral)).fixedSize()
                                        WPMaterialIcon(kind: .right).frame(width: 18, height: 18).foregroundStyle(WPColor.gray300)
                                    }
                                }.padding(.vertical, 12).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("reminder.payment.\(item.id)")
                        }
                    }
                }.padding(.horizontal, 14).background(WPColor.fill, in: RoundedRectangle(cornerRadius: 18))
            }
        } else { ForEach(0..<3) { _ in SkeletonBox(height: 62).padding(.bottom, 8) } }
    }
}

private struct ReminderSwitchStyle: ToggleStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            Capsule().fill(enabled ? (configuration.isOn ? WPColor.primary : WPColor.fgDisabled) : Color(hex: 0xF8F8F8))
                .overlay(Capsule().stroke(enabled ? .clear : Color(hex: 0xE1E1E1), lineWidth: 2))
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(enabled ? .white : Color(hex: 0xA7A5A7)).frame(width: configuration.isOn ? 24 : 16, height: configuration.isOn ? 24 : 16).padding(configuration.isOn ? 4 : 8)
                }.frame(width: 52, height: 32).frame(minHeight: 48)
        }.buttonStyle(ReminderSwitchButtonStyle()).accessibilityLabel("이메일로도 받기").accessibilityValue(configuration.isOn ? "켬" : "끔")
    }
}

private struct ReminderSwitchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.8 : 1) }
}
