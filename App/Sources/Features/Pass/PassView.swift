import SwiftUI
import StoreKit
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 요금제 시트 — 안드로이드 `ui/pass/PassPlansSheet.kt` 의 `PassPlansContent` 와 같은 모양, 결제는 App Store(StoreKit 2).
///
/// 결제 순서는 안드로이드 `PassViewModel.purchase` 와 같다 — 결제할 방을 서버에서 받고(`POST /plan/room/mine`),
/// 방이 정해진 화면에서 그 방이 서버의 내 방과 다르면 막고, 평생이면 사지 않고, 결제창에 방을 실어(`appAccountToken`) 보낸 뒤
/// 서버가 확인하면 거래를 끝낸다(`PassStore`). 결제 문구에 Google Play 는 쓰지 않는다.
///
/// **동의는 열 때마다 다시 받는다** — 기억해 두면 다음 구매는 동의 없이 결제되는 셈이다(전자상거래법 제17조 2항).
struct PassPlansView: View {
    /// 화면이 정한 방. 있으면 **방이 정해진 화면**(홈·예산·일정·청첩장)이라 서버의 내 방과 다를 때 막는다.
    /// 없으면 내 화면(프로필 · 방이 없는 혼자 쓰는 사람) — 서버의 방으로 옮겨 결제한다.
    var roomId: Int?
    /// 청첩장 칸·플랜 추가에서 열었다 — 결제를 마쳐도 홈으로 가지 않는다(안드로이드 `stayOnPurchase` · `ADD_PLAN`)
    var staysAfterPurchase = false
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.purchase) private var purchaseAction
    @State private var state: PassState?
    /// 지금 보이는 패스의 방(화면이 준 방, 아니면 귀속 방 · 내 청첩장의 방)
    @State private var room: Int?
    @State private var error: String?
    @State private var selected = "prep_pass_yearly"
    @State private var products: [String: Product] = [:]
    @State private var productsLoaded = false
    @State private var consent = false
    /// 결제창이 떠 있거나 서버 확인 중
    @State private var purchasing = false
    @State private var verifying = false
    @State private var restoring = false
    /// 결제 실패·대기·결제 없이 끝남 안내
    @State private var message: String?
    @State private var messageIsError = true
    /// 지금 안내가 결제 없이 끝났다는 말인가 — 그동안은 켜진 패스를 보고도 시트를 닫지 않는다(닫으면 결제된 것처럼 보인다)
    @State private var settledNotice = false
    /// 열 때 이미 패스를 쓰고 있었나 — 연장하려고 연 시트가 열리자마자 닫히지 않게(안드로이드 `openedActive`)
    @State private var openedActive: Bool?
    /// 시트를 내용 높이로 — 안드로이드 바닥 시트는 내용만큼만 올라온다(요금제 목록만 구르고 조작 줄은 붙어 있음)
    @State private var scrollHeight: CGFloat = 0
    @State private var controlsHeight: CGFloat = 0
    private struct Plan { let id, name, duration: String; let price: Int; let tag: String?; let solid: Bool }
    private let plans = [
        Plan(id: "prep_pass_monthly", name: "월간", duration: "30일 동안", price: 7_900, tag: nil, solid: false),
        Plan(id: "prep_pass_yearly", name: "년간", duration: "365일 · 월 3,250원꼴", price: 39_000, tag: "가장 많이 골라요", solid: true),
        Plan(id: "prep_pass_lifetime", name: "평생", duration: "결혼 뒤에도 계속", price: 69_000, tag: "기록 보관", solid: false),
    ]
    private var active: Bool { state?.hasPass == true && state?.expired != true }
    private var lifetime: Bool { active && state?.plan == "LIFETIME" }
    private var current: Plan? {
        switch state?.plan { case "MONTHLY": return plans[0]; case "YEARLY": return plans[1]; case "LIFETIME": return plans[2]; default: return nil }
    }
    private var picked: Plan { plans.first { $0.id == selected } ?? plans[1] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    head
                    if lifetime {
                        lifetimePanel.padding(.top, 14)
                    } else if state != nil {
                        VStack(spacing: 8) { ForEach(plans, id: \.id) { planRow($0) } }.padding(.top, 14)
                        features.padding(.top, 14)
                    } else if let error {
                        Text(error).wpTypography(12.5, lineHeight: 20).foregroundStyle(WPColor.danger).padding(.top, 14)
                        Button("다시 시도") { Task { await load() } }.font(WPFont.hak(13, .bold)).tint(WPColor.primary).padding(.top, 8)
                    } else {
                        VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in SkeletonBox(height: 64, corner: 16) } }.padding(.top, 14)
                    }
                }.padding(.horizontal, 18).padding(.top, 28)
                    .background(GeometryReader { g in Color.clear.onAppear { scrollHeight = g.size.height }.onChange(of: g.size.height) { _, h in scrollHeight = h } })
            }.scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: scrollHeight > 0 ? scrollHeight : nil)
            // 동의·결제·약관은 굴리지 않고 늘 보이게 둔다(안드로이드 — 시트의 조작 줄 규칙)
            if lifetime {
                VStack(alignment: .leading, spacing: 0) {
                    if let message { noticeText(message, error: messageIsError).padding(.top, 4) }
                    buyButton(label: "닫기", enabled: true) { dismiss() }.padding(.top, 14)
                }.padding(.horizontal, 18).padding(.bottom, 18)
                    .background(GeometryReader { g in Color.clear.onAppear { controlsHeight = g.size.height }.onChange(of: g.size.height) { _, h in controlsHeight = h } })
            } else if state != nil {
                VStack(alignment: .leading, spacing: 0) {
                    if active, let current { stackNote(current).padding(.top, 12) }
                    consentBox.padding(.top, active ? 10 : 16)
                    // 버튼의 금액도 App Store 가 준 값 — 줄과 버튼이 어긋나면 안 된다. 상품을 못 받았으면 결제창을 열 수 없어 잠근다
                    buyButton(label: purchasing ? (verifying ? "결제를 확인하는 중..." : "결제창을 여는 중...") : "\(priceAmount(picked).text)\(priceAmount(picked).unit) 결제하기",
                              enabled: consent && products[picked.id] != nil && !purchasing && !restoring) { Task { await buy() } }
                        .padding(.top, 12).accessibilityIdentifier("pass.buy")
                    if consent && productsLoaded && products[picked.id] == nil && message == nil {
                        noticeText(PassPurchaseRules.productUnavailable, error: false)
                    }
                    if let message { noticeText(message, error: messageIsError) }
                    Text("플랜당 1GB(약 3,000장) · 7일 이내 환불\n패스가 끝나면 올린 서류는 앱에서 보이지 않아요. 전부 내려받기는 90일 동안 됩니다.")
                        .wpTypography(10.5, lineHeight: 17).foregroundStyle(WPColor.passSheetFaint).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                    HStack(spacing: 14) {
                        Button { if let url = URL(string: AppConfig.webBaseURL + "/terms/paid") { openURL(url) } } label: {
                            Text("유료 서비스 이용약관").underline().foregroundColor(WPColor.passSheetFaint).wpTypography(10.5, lineHeight: 17)
                        }.buttonStyle(.plain)
                        // 평생 패스(비소모성)는 App Store 에서 되살릴 수 있어야 한다(심사 지침 3.1.1)
                        Button { Task { await restore() } } label: {
                            Text(restoring ? "복원하는 중..." : "구매 복원").underline().foregroundColor(WPColor.passSheetFaint).wpTypography(10.5, lineHeight: 17)
                        }.buttonStyle(.plain).disabled(purchasing || restoring).accessibilityIdentifier("pass.restore")
                    }.frame(maxWidth: .infinity)
                }.padding(.horizontal, 18).padding(.bottom, 18)
                    .background(GeometryReader { g in Color.clear.onAppear { controlsHeight = g.size.height }.onChange(of: g.size.height) { _, h in controlsHeight = h } })
            }
        }
        .background(.white).presentationCornerRadius(22).presentationDragIndicator(.visible)
        .presentationDetents(scrollHeight > 0 ? [.height(scrollHeight + controlsHeight)] : [.large])
        // 결제하는 동안 끌어내리면 결과 안내를 읽을 곳이 사라진다
        .interactiveDismissDisabled(purchasing || restoring)
        .task { await load() }
        // 결제창 밖에서 패스가 켜졌다(승인 대기가 풀림 · 복구 · 배우자) — 조용히 다시 받는다
        .onChange(of: env.passRevision) { _, _ in
            guard !purchasing, !restoring else { return }
            Task {
                await load(quiet: true)
                /*
                  없던 패스가 생겼으면 닫는다. 결제 없이 끝난 안내가 떠 있으면 읽혀야 하고, 평생이 켜졌으면 "평생 이용 중" 을
                  보여 준다(안드로이드 PassPlansSheet).
                */
                if active, openedActive == false, !settledNotice, !lifetime { dismiss() }
            }
        }
    }

    private func noticeText(_ text: String, error: Bool) -> some View {
        Text(text).wpTypography(12.5, lineHeight: 20).foregroundStyle(error ? WPColor.danger : WPColor.plansMuted)
            .fixedSize(horizontal: false, vertical: true).padding(.top, 8).accessibilityIdentifier("pass.message")
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("준비 패스").tracking(-0.38).foregroundColor(WPColor.textPrimary).wpTypography(19, .bold)
                Text("두 사람 모두 · 자동으로 갱신되지 않아요").wpTypography(12.5).foregroundStyle(WPColor.plansMuted)
            }.frame(maxWidth: .infinity, alignment: .leading)
            // 웹 `-mr-1 grid h-8 w-8 rounded-full bg-[#f7f8f9] text-[#6b6570]` + X 16
            Button { dismiss() } label: {
                WPLucideIcon(paths: DocIcon.x, size: 16, color: WPColor.plansMuted).frame(width: 32, height: 32).background(WPColor.fill, in: Circle())
            }.buttonStyle(.plain).offset(x: 4).accessibilityLabel("닫기").accessibilityIdentifier("pass.closePlans")
        }
    }

    /// 웹 `PassPlansSheet` 의 이용 중 패널(분홍 테두리 · 연분홍 면 · "평생" 알약)
    private var lifetimePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("평생 이용 중").wpTypography(15, .bold).foregroundStyle(WPColor.textPrimary)
                Spacer()
                Text("평생").wpTypography(11, .bold).foregroundStyle(WPColor.brand700).padding(.horizontal, 9).padding(.vertical, 3).background(WPColor.brand100, in: Capsule())
            }
            Text("기간 제한 없이 두 사람이 함께 쓰고 있어요. 더 살 패스가 없어요.").wpTypography(13, lineHeight: 20).foregroundStyle(WPColor.plansMuted)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(WPColor.plansPicked, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WPColor.primary, lineWidth: 1.5))
            .accessibilityIdentifier("pass.lifetime")
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 8) {
            if AdsService.enabled { feature("광고 없이 쓰기", note: "두 사람 모두 · 앱에서") }
            feature("사진·영수증 약 3,000장 보관")
            feature("예산·일정 엑셀로 받기")
            feature("잔금·중도금 결제일 알림")
            feature("시세 비교", note: "후기가 쌓이면 · 추가 요금 없음")
            feature("모바일 청첩장 1회", note: "첫 구매 혜택 · 패스가 끝나도 유지")
        }.padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func feature(_ title: String, note: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·").wpTypography(12.5, lineHeight: 17).foregroundStyle(WPColor.primary)
            // 보충 문구는 회색·작은 글씨로 뒤에 붙는다(웹 ml-1 text-[11.5px] #9aa0a6)
            (Text(title).foregroundColor(WPColor.plansBody) + Text(note.map { " " + $0 } ?? "").font(WPFont.hak(11.5)).foregroundColor(WPColor.passSheetFaint))
                .wpTypography(12.5, lineHeight: 17).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func planRow(_ plan: Plan) -> some View {
        let on = selected == plan.id
        let price = priceAmount(plan)
        return Button { selected = plan.id } label: {
            HStack(spacing: 12) {
                // 웹 라디오: 고르면 5px 분홍 테두리, 아니면 1.5px 회색 테두리
                Circle().strokeBorder(on ? WPColor.primary : WPColor.plansRadio, lineWidth: on ? 5 : 1.5).frame(width: 17, height: 17)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.name).wpTypography(14, .bold).foregroundStyle(WPColor.textPrimary)
                        if let tag = plan.tag {
                            Text(tag).wpTypography(10, .bold).foregroundStyle(plan.solid ? Color.white : WPColor.plansMuted)
                                .padding(.horizontal, 7).padding(.vertical, 2).background(plan.solid ? WPColor.primary : WPColor.plansQuietTag, in: Capsule())
                        }
                    }
                    Text(plan.duration).wpTypography(11.5).foregroundStyle(WPColor.plansMuted)
                }
                Spacer(minLength: 0)
                // 금액은 사용자 값 글꼴(Tmoney)에 합성 굵기, 단위 `원` 은 그 아래 작게
                VStack(alignment: .trailing, spacing: 0) {
                    WPTmoneyText(text: price.text, size: 17, bold: true, color: UIColor(on ? WPColor.brand700 : WPColor.textPrimary), lineHeight: 20)
                    if !price.unit.isEmpty { Text(price.unit).wpTypography(10.5, lineHeight: 13).foregroundStyle(WPColor.passSheetFaint) }
                }
            }.padding(.horizontal, 14).padding(.vertical, 12)
                .background(on ? WPColor.plansPicked : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? WPColor.primary : WPColor.plansStroke, lineWidth: 1.5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("pass.plan.\(plan.id)")
    }

    /// App Store 가 준 원화 값(`₩39,000`)은 숫자만 떼어 같은 모양으로, 못 받았으면 적어 둔 값(안드로이드 `priceParts`).
    /// 다른 나라 통화면 App Store 문자열을 그대로 두고 단위를 붙이지 않는다.
    private func priceAmount(_ plan: Plan) -> (text: String, unit: String) {
        if let product = products[plan.id] {
            let raw = product.displayPrice.trimmingCharacters(in: .whitespaces)
            if raw.hasPrefix("₩") || raw.hasPrefix("￦") || raw.hasSuffix("원") {
                let digits = raw.filter(\.isNumber)
                if let value = Int(digits) { return (wpThousands(value), "원") }
            }
            return (raw, "")
        }
        return (wpThousands(plan.price), "원")
    }

    /// 이미 월간·년간을 쓰는 사람이 또 살 때 — 지금 패스가 끝나는 대로 이어 붙는다는 것을 결제 전에 말한다.
    private func stackNote(_ current: Plan) -> some View {
        let until = KstInstant.kstDate(state?.expiresAt).map { "\($0.year)년 \($0.month)월 \($0.day)일" }
        let lead = until.map { "\(current.name) 패스가 \($0)까지 남아 있어요." } ?? "\(current.name) 패스를 쓰고 있어요."
        let tail = picked.id == "prep_pass_lifetime" ? "평생 패스는 결제하는 순간부터 기간 없이 써요." : "이번 \(picked.name) 패스는 지금 패스가 끝나는 대로 이어 붙어요."
        return (Text(lead).font(WPFont.hak(12.5, .bold)).foregroundColor(WPColor.textPrimary) + Text(" " + tail).foregroundColor(WPColor.plansBody))
            .wpTypography(12.5, lineHeight: 19).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14).padding(.vertical, 11).frame(maxWidth: .infinity, alignment: .leading)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var consentBox: some View {
        Button { consent.toggle() } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    // 안드로이드 M3 체크박스를 17pt 로 줄인 모양 — 비면 회색 테두리, 고르면 분홍 면 + 흰 체크
                    ZStack {
                        RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(WPColor.plansRadio, lineWidth: 1.7).opacity(consent ? 0 : 1)
                        if consent {
                            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(WPColor.primary)
                            WPLucideIcon(paths: DocIcon.check, size: 12, color: .white, strokeWidth: 3)
                        }
                    }.frame(width: 15, height: 15).padding(1).padding(.top, 3)
                    (Text("(필수)").font(WPFont.hak(13, .bold)).foregroundColor(WPColor.textPrimary) + Text(" 유료 서비스 이용약관과 청약철회 제한에 동의합니다").foregroundColor(WPColor.plansConsent))
                        .wpTypography(13, lineHeight: 18).fixedSize(horizontal: false, vertical: true)
                }
                Text("사진·문서를 올리거나 엑셀을 받으면 7일 안이어도 결제일부터 지난 날수만큼은 환불되지 않아요. 만 19세 미만은 법정대리인 동의가 필요합니다.")
                    .wpTypography(11.5, lineHeight: 19).foregroundStyle(WPColor.passSheetFaint).fixedSize(horizontal: false, vertical: true).padding(.leading, 27)
            }.padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(WPColor.plansConsentStroke, lineWidth: 1))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("pass.consent")
    }

    private func buyButton(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).wpTypography(15, .bold).foregroundStyle(enabled ? Color.white : WPColor.plansBuyDisabledText)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(enabled ? WPColor.primary : WPColor.plansBuyDisabled, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(PlansButtonStyle()).disabled(!enabled)
    }

    /// - Parameter quiet: 다시 받기 — 실패해도 보이던 값을 그대로 둔다(실패를 "패스 없음" 으로 읽지 않는다)
    private func load(quiet: Bool = false) async {
        if !quiet { error = nil }
        do {
            var resolved = room ?? roomId ?? env.boundRoomId
            if resolved == nil { let invitation: MyInvitation = try await env.api.send(Endpoint.myInvitation()); resolved = invitation.roomId }
            var next = PassState()
            if let resolved { next = try await env.api.send(Endpoint.pass(roomId: resolved)) }
            room = resolved
            state = next
            if openedActive == nil { openedActive = PassPurchaseRules.isActive(next) }
        } catch { if !quiet { self.error = error.localizedDescription } }
        if !lifetime && products.isEmpty {
            products = await env.passStore.loadProducts()
            productsLoaded = true
        }
    }

    /// 결제 — 안드로이드 `PassViewModel.purchase` 와 같은 순서.
    private func buy() async {
        guard !purchasing, !restoring, consent, let product = products[picked.id] else { return }
        purchasing = true; verifying = false
        message = nil; settledNotice = false
        defer { purchasing = false; verifying = false }

        /*
          **결제할 방은 늘 서버가 정한다**(`POST /plan/room/mine`, 멱등 — 웹 `startPayment` 와 같음). 서버는 귀속(SPOUSE) 방을
          먼저, 없으면 내 방을 주고 없으면 만든다. 패스는 방에 붙는데 방은 초대 참여 때에만 생겨서, 혼자 쓰는 사람은 예전에
          결제할 수 없었다.
        */
        guard let mine = await env.ensureMyRoom() else { show(.failed(PassPurchaseRules.ensureFailed)); return }
        let target = mine.roomId
        if target != room {
            // 방이 정해진 화면에서 서버의 방과 다르다 — 내 돈이 보이지 않는 방으로 가면 안 된다(웹 screenRoomId)
            if roomId != nil { show(.settled(nil, PassPurchaseRules.notMyPlan)); return }
            /*
              화면이 보여 주지 않던 방이다. 그 방의 패스를 **먼저** 본다 — 상대가 이미 산 방이면 같은 패스를 또 사게 된다.
              방·패스·안내를 한 번에 바꾼다(따로 바꾸면 켜진 패스를 본 시트가 안내를 읽히기도 전에 닫힌다).
            */
            guard let current: PassState = try? await env.api.send(Endpoint.pass(roomId: target)) else {
                show(.failed(PassPurchaseRules.ensureFailed)); return
            }
            room = target
            state = current
            if PassPurchaseRules.isActive(current) { show(.settled(current, PassPurchaseRules.alreadyActive)); return }
        }

        let outcome = await env.passStore.purchase(product, roomId: target, env: env, action: purchaseAction) { verifying = true }
        switch outcome {
        case let .success(next):
            state = next
            env.notePassPurchased(roomId: target, goHome: !staysAfterPurchase)
            dismiss()
        case .canceled:
            // 사용자가 닫은 것뿐 — 오류 안내를 띄우지 않는다
            break
        default:
            show(outcome)
        }
    }

    /// 구매 복원 — App Store 와 맞춘 뒤 평생 패스를 서버로 다시 보낸다.
    private func restore() async {
        guard !purchasing, !restoring else { return }
        restoring = true
        message = nil; settledNotice = false
        defer { restoring = false }
        let outcome = await env.passStore.restore(env: env)
        if case .canceled = outcome { return }
        show(outcome)
        await load(quiet: true)
    }

    private func show(_ outcome: PassPurchaseOutcome) {
        if case let .settled(next, _) = outcome {
            if let next { state = next }
            settledNotice = true
        }
        message = outcome.message
        messageIsError = outcome.isError
    }
}

/// 꺼진 결제 버튼은 색으로만 말한다(안드로이드 `PassBuyDisabled`) — `.plain` 의 흐림을 겹치지 않게.
private struct PlansButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.85 : 1) }
}
