import SwiftUI
import WPModels
import WPNetworking
import WPDomain
import WPUtils

/// The profile pass card and member shortcuts share the server entitlement.
struct UserPassCard: View {
    var loggedIn: Bool
    @EnvironmentObject private var env: AppEnvironment
    @State private var state: PassState?
    @State private var room: Int?
    @State private var reminder: ReminderSetting?
    @State private var error: String?
    @State private var intro = false
    @State private var plans = false
    @State private var export = false
    @State private var reminders = false
    private var lifetime: Bool { state?.plan == "LIFETIME" }
    private var label: String { lifetime ? "평생" : state?.plan == "MONTHLY" ? "월간" : "년간" }
    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                if let state {
                    HStack {
                        Text("준비 패스").wpTypography(14.5, .bold)
                        Spacer()
                        if state.hasPass {
                            Text(lifetime ? "평생" : "\(label) · 사용 중").wpTypography(11, .bold)
                                .foregroundStyle(Color(hex: 0xBA1C68)).padding(.horizontal, 9).padding(.vertical, 3)
                                .background(Color(hex: 0xFFF1F7), in: Capsule())
                        } else {
                            WPTmoneyText(text: "월 7,900원부터", size: 14, bold: true, color: UIColor(Color(hex: 0xBA1C68)))
                        }
                    }
                    if state.hasPass {
                        Text(purchaseDescription(state)).wpTypography(12, lineHeight: 19.5).foregroundStyle(Color(hex: 0x6B6570)).padding(.top, 7)
                        if lifetime {
                            Text("결혼식이 끝나도 사진·영수증·예산표가 그대로 남아요.")
                                .wpTypography(12, lineHeight: 19.5).foregroundStyle(Color(hex: 0x6B6570)).padding(.top, 4)
                        }
                        Rectangle().fill(Color(hex: 0xF0E3EA)).frame(height: 1).padding(.top, 11)
                        Button { reminders = true } label: {
                            HStack {
                                Text("결제일 알림 · \(reminderSummary)").wpTypography(12.5).foregroundStyle(Color(hex: 0x6B6570))
                                Spacer(minLength: 8)
                                if let reminder {
                                    Capsule().fill(reminder.leadDays.isEmpty ? Color(hex: 0xD8D2D7) : WPColor.primary)
                                        .frame(width: 34, height: 20)
                                        .overlay(alignment: reminder.leadDays.isEmpty ? .leading : .trailing) {
                                            Circle().fill(.white).frame(width: 16, height: 16).padding(2)
                                        }.accessibilityHidden(true)
                                } else { Image(systemName: "chevron.right").font(.system(size: 12)) }
                            }.padding(.top, 11).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("pass.reminder")
                    } else {
                        Text("사진·영수증 약 3,000장 보관 · 엑셀로 받기 · 결제일 알림" + (AdsService.enabled ? " · 광고 없이" : "") + ". 한 번 결제하면 두 사람 모두 씁니다.")
                            .wpTypography(12, lineHeight: 19.5).foregroundStyle(Color(hex: 0x6B6570)).padding(.top, 7)
                        Button { intro = true } label: {
                            Text("준비 패스 알아보기").wpTypography(13, .bold).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 36)
                                .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).padding(.top, 11).accessibilityIdentifier("user.pass")
                    }
                } else if let error {
                    Text(error).wpTypography(12).foregroundStyle(.secondary)
                    Button("다시 시도") { Task { await load() } }.padding(.top, 8)
                } else { ProgressView().frame(maxWidth: .infinity).frame(height: 113) }
            }.padding(.horizontal, 16).padding(.vertical, 15)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: 0xF0E3EA)))
                .overlay { PassHighlightBorder(radius: 20) }
            if state?.hasPass == true, let room {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle").font(.system(size: 14))
                        Text("우리 둘, 준비 패스와 함께").wpTypography(11)
                        Spacer()
                        Button { plans = true } label: { Text(label).wpTypography(9).opacity(0.8) }
                            .accessibilityIdentifier("pass.plans")
                    }
                    HStack(spacing: 6) {
                        NavigationLink { PassDownloadView(roomId: room) } label: { tool("서류 보관", "folder") }
                        Button { export = true } label: { tool("엑셀 받기", "arrow.down.doc") }
                        Button { reminders = true } label: { tool("결제일 알림", "bell") }
                    }.buttonStyle(.plain)
                }.foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 15)
                    .background(LinearGradient(colors: [Color(hex: 0xF12888), Color(hex: 0xFF9355)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))

            }
        }.task(id: loggedIn) { await load() }
            .fullScreenCover(isPresented: $intro) { PassView(roomId: room) }
            .sheet(isPresented: $plans) { PassPlansView(roomId: room) }
            .sheet(isPresented: $export) { if let room { CalendarExportSheet(roomId: room) } }
            .fullScreenCover(isPresented: $reminders, onDismiss: { Task { await load() } }) { ReminderSettingsView(roomId: room) }
    }
    private func tool(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 5) { Image(systemName: icon).font(.system(size: 13)); Text(title).wpTypography(10) }
            .frame(maxWidth: .infinity).frame(minHeight: 36).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
    }
    private var reminderSummary: String {
        guard let reminder else { return "설정 확인" }
        guard !reminder.leadDays.isEmpty else { return "알림 시점을 고르지 않았어요" }
        return reminder.leadDays.sorted(by: >).map(ReminderRules.leadLabel).joined(separator: " · ") + " " + ReminderRules.hourLabel(reminder.hour)
    }
    private func purchaseDescription(_ state: PassState) -> String {
        var prefix = ""
        if let date = KstInstant.kstDate(state.purchasedAt), let buyer = state.buyerName { prefix = "\(date.dateString) \(buyer)님이 구매 · " }
        return prefix + (lifetime ? "기간 제한 없음" : KstInstant.kstDate(state.expiresAt).map { "\($0.dateString)까지" } ?? "준비 패스 이용 중")
    }
    private func load() async {
        error = nil
        guard loggedIn else { state = PassState(); return }
        do {
            let invitation: MyInvitation = try await env.api.send(Endpoint.myInvitation())
            room = invitation.roomId
            if let room { state = try await env.api.send(Endpoint.pass(roomId: room)) }
            else { state = PassState() }
            if state?.hasPass == true { reminder = try? await env.api.send(Endpoint.reminderSetting()) }
        } catch { self.error = error.localizedDescription }
    }
}
