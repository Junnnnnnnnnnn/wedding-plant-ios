import SwiftUI
import WPNetworking

/// 안드로이드 `ui/moderation/ModerationMenu.kt` 와 한 글자도 다르지 않게 둔다.
enum ModerationText {
    /// 신고를 받은 뒤 — **무엇이 일어났는지** 정확히 적는다
    static let reportDone = "신고를 접수했어요. 이 글은 회원님 화면에서 바로 사라집니다."
    /// 채팅 말풍선은 신고해도 지우지 않는다 — "바로 사라진다" 고 말하지 않는다
    static let reportDoneChat = "신고를 접수했어요. 운영자가 확인한 뒤 필요하면 조치합니다."
    static let reportIntro = "신고한 글은 회원님 화면에서 바로 사라져요. 확인 뒤 필요하면 모두에게 보이지 않도록 조치합니다."
    static let reportIntroChat = "운영자가 확인한 뒤 필요하면 조치합니다. 대화 흐름이 끊기지 않게 메시지는 그대로 남아요."
    static let blockDone = "차단했어요. 프로필 > 차단 관리에서 풀 수 있어요."
    /// **"상대에게 알려지지 않는다" 를 반드시 적는다.** 알려질까 봐 못 누르면 차단 버튼이 없는 것과 같다.
    static let blockConfirm = "앞으로 이 사람이 올리는 글이 회원님 화면에 보이지 않아요. " +
        "상대에게는 알려지지 않고, 프로필 > 차단 관리에서 언제든 풀 수 있어요."
}

/// 시트가 지금 보여 주는 단계. 안드로이드 `Phase`
enum ModerationPhase { case menu, reason, block, done }

/// 안드로이드 `ReportReason` — 순서·글자 그대로
enum ReportReasonOption: String, CaseIterable, Identifiable {
    case spam = "SPAM", abuse = "ABUSE", sexual = "SEXUAL", falseInfo = "FALSE_INFO", privacy = "PRIVACY", other = "OTHER"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .spam: "스팸이거나 광고예요"
        case .abuse: "욕설·비방이 있어요"
        case .sexual: "선정적이거나 불쾌해요"
        case .falseInfo: "금액·업체 정보가 사실과 달라요"
        case .privacy: "남의 개인정보가 드러나 있어요"
        case .other: "그 밖의 이유"
        }
    }
}

/// Material 아이콘 원본 경로(24×24) — 안드로이드 `Icons.*` 와 같은 모양.
enum ModerationIconPaths {
    static let moreHoriz = ["M6 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm12 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm-6 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"]
    /// `Icons.Outlined.Flag`
    static let flag = ["M12.36 6l.4 2H18v6h-3.36l-.4-2H7V6h5.36M14 4H5v17h2v-7h5.6l.4 2h7V6h-5.6L14 4z"]
    /// `Icons.Outlined.Block`
    static let block = ["M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zM4 12c0-4.42 3.58-8 8-8 1.85 0 3.55.63 4.9 1.69L5.69 16.9C4.63 15.55 4 13.85 4 12zm8 8c-1.85 0-3.55-.63-4.9-1.69L18.31 7.1C19.37 8.45 20 10.15 20 12c0 4.42-3.58 8-8 8z"]
}

/// 신고·차단 메뉴 — 공개 글마다 붙는 `···`. 안드로이드 `ModerationMenu` 이식.
///
/// Google Play·App Store 의 사용자 제작 콘텐츠 정책이 **앱 안의** 신고·차단을 요구한다.
/// 후기 카드·후기 상세·자랑 카드·자랑 상세·채팅 말풍선이 전부 이것을 쓴다.
///
/// 예전에는 iOS `Menu` + 확인 대화상자 + `Form` 시트로 세 가지 모양이 섞였다. 안드로이드처럼
/// **바닥 시트 한 장에서 단계만 갈아 끼운다**(메뉴 → 사유/차단 확인 → 완료).
struct ModerationMenu: View {
    let targetType: String
    let targetId: Int
    /// 처리가 끝나 이 글이 화면에서 사라져야 할 때
    var onHidden: () -> Void = {}
    /// 예전 호출부 호환용 — 크기는 안드로이드처럼 늘 28pt 단추
    var compact = false
    /// 분홍 머리 면 위에 얹을 때
    var onDark = false
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            WPMaterialPathIcon(paths: ModerationIconPaths.moreHoriz, size: 17,
                               color: onDark ? Color.white.opacity(0.75) : WPColor.fgSubtle)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("신고 또는 차단")
        .accessibilityIdentifier("moderation.menu")
        .sheet(isPresented: $open) {
            ModerationSheet(targetType: targetType, targetId: targetId, start: .menu, onHidden: onHidden)
        }
    }
}

/// 채팅 말풍선처럼 메뉴 없이 곧바로 사유부터 여는 자리(채팅은 차단이 없다 — 방을 나가는 것이 맞다).
struct ReportContentSheet: View {
    let targetType: String
    let targetId: Int
    var onHidden: () -> Void
    var body: some View {
        ModerationSheet(targetType: targetType, targetId: targetId, start: .reason, onHidden: onHidden)
    }
}

/// 바닥에서 올라오는 한 장. 단계만 갈아 끼운다 — 시트를 겹치면 몇 번 닫아야 하는지 모른다.
struct ModerationSheet: View {
    let targetType: String
    let targetId: Int
    var start: ModerationPhase
    var onHidden: () -> Void

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var phase: ModerationPhase?
    @State private var reason: ReportReasonOption?
    @State private var detail = ""
    @State private var busy = false
    @State private var error: String?
    @State private var doneMessage = ""
    @State private var blocked = false
    @State private var height: CGFloat = 160

    private var isChat: Bool { targetType == "CHAT" || targetType == "CHAT_MESSAGE" }
    /// 안드로이드 `ReportTarget.CHAT` 과 같은 값으로 보낸다. 예전 호출부(`CHAT_MESSAGE`)도 받는다.
    private var serverTarget: String { isChat ? "CHAT" : targetType }

    var body: some View {
        ModerationSheetBody(
            phase: phase ?? start, allowBlock: !isChat, isChat: isChat,
            reason: reason, detail: $detail, busy: busy, error: error, doneMessage: doneMessage,
            onPhase: { phase = $0 }, onReason: { reason = $0 },
            onDismiss: { dismiss() }, onHidden: { dismiss() },
            onSubmitReport: { Task { await submitReport() } },
            onSubmitBlock: { Task { await submitBlock() } }
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = ceil($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .presentationBackground(.white)
        .interactiveDismissDisabled(busy)
        // **접수 화면에서 닫는 것은 곧 '확인'이다**(안드로이드와 같음). 끌어내려 닫아도 글은 사라진다.
        .onDisappear {
            guard (phase ?? start) == .done else { return }
            if !isChat { onHidden() }
            // 목록 갱신은 시트가 내려간 뒤에 — 먼저 올리면 카드와 함께 시트가 끊기듯 사라진다.
            if !isChat || blocked { env.moderationRevision += 1 }
        }
    }

    private func submitReport() async {
        guard let picked = reason, !busy else { return }
        busy = true; error = nil
        struct Body: Encodable { let targetType: String; let targetId: Int; let reason: String; let detail: String? }
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await env.api.sendIgnoringData(HTTPRequest.json(.post, "/plan/moderation/report",
                body: Body(targetType: serverTarget, targetId: targetId, reason: picked.rawValue, detail: trimmed.isEmpty ? nil : trimmed)))
            doneMessage = isChat ? ModerationText.reportDoneChat : ModerationText.reportDone
            phase = .done
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? "처리하지 못했어요."
        }
        busy = false
    }

    private func submitBlock() async {
        guard !busy else { return }
        busy = true; error = nil
        struct Body: Encodable { let targetType: String; let targetId: Int }
        do {
            try await env.api.sendIgnoringData(HTTPRequest.json(.post, "/plan/moderation/block",
                body: Body(targetType: serverTarget, targetId: targetId)))
            doneMessage = ModerationText.blockDone
            blocked = true
            phase = .done
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? "처리하지 못했어요."
        }
        busy = false
    }
}

/// 시트 본문 — **상태를 갖지 않는다.** 스크린샷 테스트가 단계별 모양을 네트워크 없이 찍는다
/// (안드로이드 `ModerationSheetBody` · `ModerationShotTest` 와 같은 이유).
struct ModerationSheetBody: View {
    var phase: ModerationPhase
    var allowBlock = true
    var isChat = false
    var reason: ReportReasonOption?
    @Binding var detail: String
    var busy = false
    var error: String?
    var doneMessage = ""
    var onPhase: (ModerationPhase) -> Void = { _ in }
    var onReason: (ReportReasonOption) -> Void = { _ in }
    var onDismiss: () -> Void = {}
    var onHidden: () -> Void = {}
    var onSubmitReport: () -> Void = {}
    var onSubmitBlock: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, phase == .menu ? 28 : 0)
            if phase != .menu { footer.padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 28) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch phase {
            case .menu:
                menuRow(ModerationIconPaths.flag, "신고하기", id: "moderation.report") { onPhase(.reason) }
                if allowBlock {
                    menuRow(ModerationIconPaths.block, "이 작성자 차단", id: "moderation.block") { onPhase(.block) }
                }
            case .reason:
                title("어떤 점이 문제인가요?")
                Color.clear.frame(height: 6)
                Text((isChat ? ModerationText.reportIntroChat : ModerationText.reportIntro).wpKeepAll)
                    .wpTypography(13, lineHeight: 19).foregroundStyle(WPColor.fgSubtle)
                    .fixedSize(horizontal: false, vertical: true)
                Color.clear.frame(height: 14)
                ForEach(ReportReasonOption.allCases) { item in reasonRow(item) }
                if reason == .other {
                    Color.clear.frame(height: 10)
                    detailField
                }
            case .block:
                title("이 작성자를 차단할까요?")
                Color.clear.frame(height: 8)
                Text(ModerationText.blockConfirm.wpKeepAll)
                    .wpTypography(13.5, lineHeight: 20).foregroundStyle(WPColor.fgMuted)
                    .fixedSize(horizontal: false, vertical: true)
            case .done:
                Color.clear.frame(height: 8)
                Text(doneMessage)
                    .wpTypography(14.5, lineHeight: 21).foregroundStyle(WPColor.fgMuted)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch phase {
            case .reason:
                errorLine
                Color.clear.frame(height: 10)
                twoButtons(right: busy ? "보내는 중..." : "신고하기", enabled: reason != nil && !busy,
                           color: WPColor.primary, id: "moderation.submit", action: onSubmitReport)
            case .block:
                errorLine
                Color.clear.frame(height: 10)
                twoButtons(right: busy ? "처리 중..." : "차단하기", enabled: !busy,
                           color: WPColor.fgNeutral, id: "moderation.block.confirm", action: onSubmitBlock)
            case .done:
                Color.clear.frame(height: 12)
                Button(action: onHidden) {
                    Text("확인").wpTypography(14, .bold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }.buttonStyle(.plain).accessibilityIdentifier("moderation.done")
            case .menu:
                EmptyView()
            }
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).wpTypography(17, .bold).foregroundStyle(WPColor.fgNeutral)
    }

    private func menuRow(_ icon: [String], _ label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                WPMaterialPathIcon(paths: icon, size: 17, color: WPColor.fgSubtle)
                Text(label).wpTypography(15).foregroundStyle(WPColor.fgNeutral)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4).padding(.vertical, 15)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }

    /// M3 `RadioButton` — 48pt 누름 자리 가운데 지름 20pt 원(테두리 2pt), 고르면 지름 12pt 점.
    private func reasonRow(_ item: ReportReasonOption) -> some View {
        let on = reason == item
        return Button { onReason(item) } label: {
            HStack(spacing: 0) {
                ZStack {
                    Circle().strokeBorder(on ? WPColor.primary : WPColor.strokeWeak, lineWidth: 2).frame(width: 20, height: 20)
                    if on { Circle().fill(WPColor.primary).frame(width: 12, height: 12) }
                }.frame(width: 48, height: 48)
                Text(item.label).wpTypography(14).foregroundStyle(on ? WPColor.primary : WPColor.fgMuted)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(on ? WPColor.brand100 : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("moderation.reason.\(item.rawValue)")
            .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var detailField: some View {
        ZStack(alignment: .topLeading) {
            if detail.isEmpty {
                Text("어떤 점이 문제인지 알려 주세요").wpTypography(14).foregroundStyle(WPColor.fgDisabled)
                    .allowsHitTesting(false)
            }
            TextField("", text: Binding(get: { detail }, set: { detail = String($0.prefix(500)) }), axis: .vertical)
                .font(Font(WPTypeface.hak.uiFont(14, .regular))).foregroundStyle(WPColor.fgNeutral)
                .tint(WPColor.primary).lineLimit(1...3)
                .accessibilityIdentifier("moderation.detail")
        }
        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .topLeading)
        .padding(14)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private var errorLine: some View {
        if let error {
            Color.clear.frame(height: 10)
            Text(error).wpTypography(13).foregroundStyle(WPColor.danger)
        }
    }

    private func twoButtons(right: String, enabled: Bool, color: Color, id: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: onDismiss) {
                Text("취소").wpTypography(14, .bold).foregroundStyle(WPColor.fgMuted)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(WPColor.strokeWeak, lineWidth: 1))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("moderation.cancel")
            Button(action: action) {
                Text(right).wpTypography(14, .bold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(enabled ? color : color.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }.buttonStyle(.plain).disabled(!enabled).accessibilityIdentifier(id)
        }
    }
}

struct BlockListView: View {
    struct Blocked: Decodable, Sendable, Identifiable { let id: Int; let displayName: String }
    @EnvironmentObject private var env: AppEnvironment
    @State private var items: [Blocked] = []
    @State private var error: String?
    @State private var pending: Blocked?
    var body: some View {
        List {
            if items.isEmpty && error == nil { Text("차단한 사용자가 없어요") }
            ForEach(items) { item in HStack { Text(item.displayName); Spacer(); Button("해제") { pending = item } } }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("차단 관리").task { await load() }
            .confirmationDialog("차단을 해제할까요?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
                Button("차단 해제") {
                    guard let item = pending else { return }
                    Task {
                        do { try await env.api.sendIgnoringData(HTTPRequest(method: .delete, path: "/plan/moderation/block/\(item.id)")); env.moderationRevision += 1; await load() }
                        catch { self.error = error.localizedDescription }; pending = nil
                    }
                }
            }
    }
    private func load() async { do { items = try await env.api.send(HTTPRequest(path: "/plan/moderation/block/list")) } catch { self.error = error.localizedDescription } }
}
