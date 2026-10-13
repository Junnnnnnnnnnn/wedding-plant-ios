import SwiftUI
import StoreKit
import WPModels
import WPNetworking
import WPUtils

struct PassPlansView: View {
    var roomId: Int?
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var state: PassState?
    @State private var resolvedRoom: Int?
    @State private var error: String?
    @State private var selected = "prep_pass_yearly"
    @State private var products: [Product] = []
    @State private var consent = false
    @State private var reminders = false
    private let plans = [("prep_pass_monthly", "월간", "30일 동안"), ("prep_pass_yearly", "년간", "365일 동안"), ("prep_pass_lifetime", "평생", "결혼 뒤에도 계속")]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image("pass_card_logo").resizable().scaledToFit().frame(height: 80)
                    Text("둘이 준비하는 모든 순간,\n준비 패스").font(WPFont.hak(30, .bold))
                    Text("두 사람 모두 · 자동으로 갱신되지 않아요").font(WPFont.hak(14)).foregroundStyle(.secondary)
                    if let state, state.hasPass {
                        Text("준비 패스 이용 중").font(WPFont.hak(22, .bold)).foregroundStyle(WPColor.primary)
                        if let buyer = state.buyerName { Text("\(buyer)님이 구매") }
                        if let expires = KstInstant.kstDate(state.expiresAt) { Text("이용 기한 \(expires.dateString)") }
                        if let resolvedRoom { PassExportButton(roomId: resolvedRoom) }
                        Button("결제일 알림 설정") { reminders = true }.buttonStyle(InvitationActionStyle())
                    }
                    if let resolvedRoom {
                        NavigationLink("보관한 서류 전부 내려받기") { PassDownloadView(roomId: resolvedRoom) }
                    }
                    ForEach(["사진·영수증 약 3,000장 보관", "예산·일정 엑셀로 받기", "잔금·중도금 결제일 알림", "모바일 청첩장 한 장"], id: \.self) { Label($0, systemImage: "checkmark.circle") }
                    ForEach(plans, id: \.0) { plan in
                        Button { selected = plan.0 } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) { Text(plan.1).font(WPFont.hak(20, .bold)); Text(plan.2).font(WPFont.hak(13)) }
                                Spacer()
                                Text(products.first { $0.id == plan.0 }?.displayPrice ?? "가격 확인 중")
                            }.padding(20).background(selected == plan.0 ? WPColor.primary.opacity(0.07) : Color.gray.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected == plan.0 ? WPColor.primary : .clear))
                        }.buttonStyle(.plain)
                    }
                    Toggle("유료 서비스 이용약관과 청약철회 제한에 동의합니다", isOn: $consent).font(WPFont.hak(13))
                    Text("사진·문서를 올리거나 엑셀을 받으면 7일 안이어도 결제일부터 지난 날수만큼은 환불되지 않아요. 만 19세 미만은 법정대리인 동의가 필요합니다.").font(WPFont.hak(11)).foregroundStyle(.secondary)
                    if let error { Text(error).font(WPFont.hak(13)).foregroundStyle(.red) }
                    // Server currently exposes google/verify only. Never charge without a verifiable entitlement.
                    Text("iOS 구매 연결을 준비하고 있어요. 이미 이용 중인 패스는 두 사람 모두 그대로 쓸 수 있어요.").font(WPFont.hak(14))
                    Text("플랜당 1GB(약 3,000장)\n패스가 끝나면 올린 서류는 앱에서 보이지 않아요. 전부 내려받기는 90일 동안 됩니다.").font(WPFont.hak(11)).foregroundStyle(.secondary)
                    if let url = URL(string: AppConfig.webBaseURL + "/terms/paid") { Link("유료 서비스 이용약관", destination: url) }
                }.padding(24)
            }.navigationTitle("준비 패스").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }.task {
            do {
                resolvedRoom = roomId ?? env.boundRoomId
                if resolvedRoom == nil {
                    let user: PlanUser = try await env.api.send(Endpoint.user())
                    resolvedRoom = user.roomId
                }
                if let resolvedRoom { state = try await env.api.send(Endpoint.pass(roomId: resolvedRoom)) }
                products = try await Product.products(for: plans.map(\.0))
            } catch { self.error = error.localizedDescription }
        }.fullScreenCover(isPresented: $reminders) { ReminderSettingsView(roomId: resolvedRoom) }
    }
}
