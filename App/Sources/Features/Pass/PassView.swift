import SwiftUI
import StoreKit
import WPModels
import WPNetworking

/// Android's compact plans sheet. StoreKit checkout remains disabled until server verification is available.
struct PassPlansView: View {
    var roomId: Int?
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var state: PassState?
    @State private var error: String?
    @State private var selected = "prep_pass_yearly"
    @State private var products: [Product] = []
    @State private var consent = false
    private let plans = [("prep_pass_monthly", "월간", "30일 동안"), ("prep_pass_yearly", "년간", "365일 동안"), ("prep_pass_lifetime", "평생", "결혼 뒤에도 계속")]
    private var lifetime: Bool { state?.hasPass == true && state?.plan == "LIFETIME" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("준비 패스").wpTypography(19, .bold).tracking(-0.38)
                        Text("두 사람 모두 · 자동으로 갱신되지 않아요").wpTypography(12.5).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16)).foregroundStyle(Color(hex: 0x746C76)).frame(width: 32, height: 32).background(Color(hex: 0xF7F8F9), in: Circle())
                    }.accessibilityLabel("닫기").accessibilityIdentifier("pass.closePlans")
                }
                if lifetime {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("평생 이용 중").wpTypography(15, .bold); Spacer(); Text("평생").wpTypography(11, .bold).foregroundStyle(WPColor.primary).padding(.horizontal, 9).padding(.vertical, 3).background(Color(hex: 0xFFF1F7), in: Capsule()) }
                        Text("기간 제한 없이 두 사람이 함께 쓰고 있어요. 더 살 패스가 없어요.").wpTypography(13, lineHeight: 20.5).foregroundStyle(.secondary)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: 0xFFFAFC), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.primary, lineWidth: 1.5))
                        .accessibilityIdentifier("pass.lifetime")
                    Button { dismiss() } label: {
                        Text("닫기").wpTypography(15, .bold).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 46)
                            .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                } else if state != nil {
                    VStack(spacing: 8) { ForEach(plans, id: \.0) { plan in planRow(plan) } }
                } else if let error {
                    Text(error).wpTypography(12).foregroundStyle(.red)
                    Button("다시 시도") { Task { await load() } }
                } else { ProgressView().frame(maxWidth: .infinity).padding(24) }
                if state != nil && !lifetime {
                    VStack(alignment: .leading, spacing: 8) {
                        if AdsService.enabled { feature("광고 없이 쓰기", note: "두 사람 모두 · 앱에서") }
                        feature("사진·영수증 약 3,000장 보관")
                        feature("예산·일정 엑셀로 받기")
                        feature("잔금·중도금 결제일 알림")
                        feature("시세 비교", note: "후기가 쌓이면 · 추가 요금 없음")
                        feature("모바일 청첩장 1회", note: "첫 구매 혜택 · 패스가 끝나도 유지")
                    }.padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: 0xF7F8F9), in: RoundedRectangle(cornerRadius: 13))
                    if !lifetime {
                        if state?.hasPass == true {
                            Text("지금 쓰는 패스의 남은 기간에 새 패스 기간이 더해져요.").wpTypography(12.5, lineHeight: 20.0).padding(12).background(Color(hex: 0xF7F8F9), in: RoundedRectangle(cornerRadius: 12))
                        }
                        Button { consent.toggle() } label: {
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: consent ? "checkmark.square.fill" : "square").font(.system(size: 17)).foregroundStyle(WPColor.primary)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("유료 서비스 이용약관과 청약철회 제한에 동의합니다").wpTypography(13)
                                    Text("사진·문서를 올리거나 엑셀을 받으면 7일 안이어도 결제일부터 지난 날수만큼은 환불되지 않아요.").wpTypography(11.5, lineHeight: 19.0).foregroundStyle(.secondary)
                                }
                            }.padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(hex: 0xF0E6EB)))
                        }.buttonStyle(.plain)
                        Text("iOS 구매 준비 중").wpTypography(15, .bold).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 46).background(WPColor.primary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        Text("iOS 구매 연결을 준비하고 있어요. 이미 이용 중인 패스는 두 사람 모두 그대로 쓸 수 있어요.").wpTypography(11.5, lineHeight: 19.0).foregroundStyle(.secondary)
                    }
                    Text("플랜당 1GB(약 3,000장) · 패스가 끝나면 올린 서류는 앱에서 보이지 않아요. 전부 내려받기는 90일 동안 됩니다.").wpTypography(10.5, lineHeight: 18.0).foregroundStyle(.secondary)
                    if let url = URL(string: AppConfig.webBaseURL + "/terms/paid") { Link("유료 서비스 이용약관", destination: url).wpTypography(10.5) }
                }
            }.padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 18)
        }.background(.white).presentationCornerRadius(22).presentationDragIndicator(.visible)
            .presentationDetents(lifetime ? [.height(270)] : [.large])
            .task { await load() }
    }
    private func feature(_ title: String, note: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·").wpTypography(12.5, lineHeight: 17).foregroundStyle(WPColor.primary)
            (Text(title).foregroundColor(Color(hex: 0x544B55)) + Text(note.map { " " + $0 } ?? "").font(WPFont.hak(11.5)).foregroundColor(Color(hex: 0x9AA0A6)))
                .wpTypography(12.5, lineHeight: 17).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func planRow(_ plan: (String, String, String)) -> some View {
        Button { selected = plan.0 } label: {
            HStack(spacing: 12) {
                Circle().stroke(selected == plan.0 ? WPColor.primary : Color(hex: 0xD8D2D7), lineWidth: selected == plan.0 ? 5 : 1.5).frame(width: 17, height: 17)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.1).wpTypography(14, .bold)
                        if plan.0 == "prep_pass_yearly" { Text("가장 많이 골라요").wpTypography(10, .bold).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 3).background(WPColor.primary, in: Capsule()) }
                        if plan.0 == "prep_pass_lifetime" { Text("기록 보관").wpTypography(10, .bold).foregroundStyle(Color(hex: 0x746C76)).padding(.horizontal, 6).padding(.vertical, 3).background(Color(hex: 0xF7F8F9), in: Capsule()) }
                    }
                    Text(plan.2).wpTypography(11.5).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(products.first { $0.id == plan.0 }?.displayPrice ?? "가격 준비 중").wpTypography(13, .bold)
            }.padding(.horizontal, 14).padding(.vertical, 12).frame(minHeight: 64)
                .background(selected == plan.0 ? Color(hex: 0xFFFAFC) : .white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected == plan.0 ? WPColor.primary : Color(hex: 0xEFEAEE), lineWidth: 1.5))
        }.buttonStyle(.plain).accessibilityIdentifier("pass.plan.\(plan.0)")
    }
    private func load() async {
        error = nil
        do {
            var room = roomId ?? env.boundRoomId
            if room == nil { let invitation: MyInvitation = try await env.api.send(Endpoint.myInvitation()); room = invitation.roomId }
            if let room { state = try await env.api.send(Endpoint.pass(roomId: room)) } else { state = PassState() }
        } catch { self.error = error.localizedDescription }
        if !lifetime { products = (try? await Product.products(for: plans.map(\.0))) ?? [] }
    }
}
