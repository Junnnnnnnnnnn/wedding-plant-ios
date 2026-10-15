import SwiftUI
import WPModels
import WPNetworking
import WPUtils

/// **어느 플랜을** 이 대화방에 올릴까 — 채팅 입력줄의 `+` 로 연다.
/// 안드로이드 `ui/chat/PickPlanSheet.kt`(웹 `PickPlanForChatSheet`) 이식.
///
/// - 대화 중에 찾는 것이라 최근 것이 위다 — 서버 기본 정렬(등록 역순), 50개.
/// - 보내는 동안에는 끌어 내려 닫지 못하지만 **닫기 X 는 닫는다**(안드로이드·웹과 같음).
struct PickPlanSheet: View {
    let roomId: Int?
    @ObservedObject var model: ChatViewModel
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var items: [ScheduleItem]?
    @State private var height: CGFloat = 320

    var body: some View {
        VStack(spacing: 0) {
            WPSheetHandle()
            PickPlanSheetBody(
                items: items,
                sending: model.sharingSchedule,
                done: model.sharedSchedule,
                error: model.shareError,
                onClose: { dismiss() },
                onPick: { model.shareSchedule($0) }
            )
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = ceil($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .wpBottomSheet(height: height, corner: 22)
        .interactiveDismissDisabled(model.sharingSchedule != nil)
        .task {
            model.sharedSchedule = nil; model.shareError = nil
            // 못 받으면 빈 목록으로 둔다(안드로이드·웹과 같음)
            let path = roomId.map { "/plan/schedule/room/\($0)/list" } ?? "/plan/schedule/list"
            let page: SchedulePage? = try? await env.api.send(HTTPRequest(path: path, query: ["count": "50"]))
            items = page?.list ?? []
        }
        .onChange(of: model.sharedSchedule) { _, id in
            // 올라가면 체크를 0.9초 보이고 닫는다(안드로이드 `SHARE_DONE_HOLD_MS`)
            if id != nil { Task { try? await Task.sleep(for: .milliseconds(900)); dismiss() } }
        }
        .sensoryFeedback(.success, trigger: model.sharedSchedule) { _, new in new != nil }
    }
}

/// 시트 본문 — **상태를 갖지 않는다**(스크린샷 테스트가 단계별로 그린다). 안드로이드 `PickPlanSheetBody`.
struct PickPlanSheetBody: View {
    var items: [ScheduleItem]?
    var sending: Int?
    var done: Int?
    var error: String?
    var onClose: () -> Void = {}
    var onPick: (Int) -> Void = { _ in }
    /// 목록이 길면 목록만 구른다 — 머리글(닫기 X)은 남는다.
    var maxListHeight: CGFloat = 560
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("어떤 플랜을 올릴까요?").tracking(-0.34).wpTypography(17, .bold)
                    .foregroundStyle(WPColor.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
                WPSheetCloseButton(action: onClose)
            }
            Color.clear.frame(height: 16)
            ScrollView {
                list.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = ceil($0) }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(max(listHeight, 1), maxListHeight))
            if let error {
                Text(error.wpKeepAll).wpTypography(12.5).foregroundStyle(WPColor.danger)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    @ViewBuilder private var list: some View {
        if let items {
            if items.isEmpty {
                VStack(spacing: 0) {
                    WPEmptyIconCircle(paths: WPIconPaths.clipboardList)
                    Text("아직 만든 플랜이 없어요.").wpTypography(13.5).foregroundStyle(WPColor.stone600).padding(.top, 12)
                    Text("홈에서 플랜을 추가하면 여기서 골라 올릴 수 있어요.".wpKeepAll).wpTypography(12.5, lineHeight: 20)
                        .foregroundStyle(WPColor.gray400).multilineTextAlignment(.center).padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 6) {
                    ForEach(items) { item in
                        PickRow(item: item, done: done == item.id, enabled: sending == nil && done == nil) { onPick(item.id) }
                    }
                }
            }
        } else {
            // 받기 전에는 "없다" 고 말하지 않는다 — 뼈대
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in SkeletonBox(height: 58, corner: 16) }
            }
        }
    }
}

private struct PickRow: View {
    let item: ScheduleItem
    let done: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).wpTypography(14.5, .bold).foregroundStyle(WPColor.textPrimary).lineLimit(1)
                    Text(Self.subline(item)).wpTypography(12).foregroundStyle(WPColor.gray400).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if done {
                    WPLucideIcon(paths: WPIconPaths.lucideCheck, size: 16, color: WPColor.primary).accessibilityLabel("올림")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.strokeSubtle, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(enabled || done ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        // `.disabled` 는 plain 단추의 글자를 한 번 더 흐린다 — 흐림은 위 opacity 하나로(안드로이드 alpha 0.6)
        .allowsHitTesting(enabled)
        .accessibilityIdentifier("pick.\(item.id)")
    }

    /// `스드메 · 9월 12일 · 300만원` — 연도 없이, 날짜가 없으면 `날짜 미정`, 금액은 0 보다 클 때만.
    static func subline(_ item: ScheduleItem) -> String {
        var text = item.categoryName
        if let raw = item.startDate {
            let parts = raw.prefix(10).split(separator: "-")
            if parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) { text += " · \(month)월 \(day)일" }
            else { text += " · " + raw }
        } else { text += " · 날짜 미정" }
        if let amount = item.amount, amount > 0 { text += " · \(withThousands(amount))만원" }
        return text
    }
}

// MARK: - 공용 조각 (채팅·공유·프로필 시트)

/// 안드로이드 `AppBottomSheet` 의 손잡이 — 38×4, `#e2ddE1`, 위 10 · 아래 14.
struct WPSheetHandle: View {
    var bottom: CGFloat = 14
    var body: some View {
        Capsule().fill(WPColor.sheetHandle).frame(width: 38, height: 4)
            .frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, bottom)
            .accessibilityHidden(true)
    }
}

/// 시트 머리의 닫기 X — 32 원, lucide X 16, `Gray400`.
struct WPSheetCloseButton: View {
    var size: CGFloat = 32
    var background: Color = .clear
    var label = "닫기"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            WPLucideIcon(paths: WPIconPaths.lucideX, size: 16, color: WPColor.gray400)
                .frame(width: size, height: size).background(background, in: Circle()).contentShape(Circle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}

/// 빈 상태의 44 원(`#f7f5f6`) + 아이콘 20(`Gray400`).
struct WPEmptyIconCircle: View {
    var paths: [String]
    var background: Color = WPColor.chatShareEmptyBg
    var tint: Color = WPColor.gray400
    var material = false
    var body: some View {
        Group {
            if material { WPMaterialPathIcon(paths: paths, size: 20, color: tint) }
            else { WPLucideIcon(paths: paths, size: 20, color: tint) }
        }
        .frame(width: 44, height: 44).background(background, in: Circle())
    }
}

extension View {
    /// 안드로이드 `AppBottomSheet` 처럼 내용 높이만큼 올라오는 흰 시트(손잡이는 내용이 직접 그린다).
    func wpBottomSheet(height: CGFloat, corner: CGFloat, background: Color = .white) -> some View {
        self.background(background)
            .presentationDetents([.height(max(height, 80))])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(corner)
            .presentationBackground(background)
    }
}

/// 이 묶음(채팅·커플·프로필·내보내기)이 쓰는 안드로이드 `WpColors` 값.
extension WPColor {
    /// 안드로이드 `SheetHandle`
    static let sheetHandle = Color(hex: 0xE2DDE1)
    /// 안드로이드 `ChatShareSub` — 일정 제목·활동 줄
    static let chatShareSub = Color(hex: 0x7A6C74)
    /// 안드로이드 `ChatShareEmptyBg` — 빈 상태 동그라미
    static let chatShareEmptyBg = Color(hex: 0xF7F5F6)
    /// 안드로이드 `ChatHeaderRing` — 채팅 머리 얼굴의 바깥 링
    static let chatHeaderRing = Color(hex: 0xF43D93)
    /// 안드로이드 `ChatPartnerAvatar` — 상대 얼굴 바탕
    static let chatPartnerAvatar = Color(hex: 0x6D5CE8)
    /// 안드로이드 `ChatActivityName` — 활동 줄의 이름
    static let chatActivityName = Color(hex: 0x4A3D44)
    /// 안드로이드 `WarnBg` · `WarnTitle` · `WarnBody`
    static let warnBg = Color(hex: 0xFFF8E6)
    static let warnTitle = Color(hex: 0x8A6100)
    static let warnBody = Color(hex: 0x7A6C54)
    /// 안드로이드 `PassCardStroke` · `PassSheetMuted`
    static let passCardStroke = Color(hex: 0xF0E3EA)
    static let passSheetMuted = Color(hex: 0x6B6570)
    /// 공유 시트 — 안드로이드 `InviteBarEnd` · `InvitePink` · `InviteIndigo(Light)` · `InviteGreen(Light)`
    static let inviteBarEnd = Color(hex: 0xFF94A1)
    static let invitePink = Color(hex: 0xFF6B9D)
    static let inviteIndigo = Color(hex: 0x6366F1)
    static let inviteIndigoLight = Color(hex: 0x818CF8)
    static let inviteGreen = Color(hex: 0x059669)
    static let inviteGreenLight = Color(hex: 0x10B981)
}

/// 이 묶음이 쓰는 lucide · Material 원본 경로(안드로이드 `LucideIcons` · `Icons.*` 와 같은 문자열).
extension WPIconPaths {
    static let lucideX = ["M18 6 6 18", "m6 6 12 12"]
    static let lucideCheck = ["M20 6 9 17l-5-5"]
    static let lucidePlus = ["M5 12h14", "M12 5v14"]
    static let lucideSend = [
        "M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z",
        "m21.854 2.147-10.94 10.939",
    ]
    static let clipboardList = [
        "M9 2h6a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z",
        "M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2",
        "M12 11h4", "M12 16h4", "M8 11h.01", "M8 16h.01",
    ]
    static let ellipsisVertical = [
        "M11 12a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
        "M11 5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
        "M11 19a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
    ]
    static let heart = ["M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5"]
    static let calendarRange = [
        "M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2z",
        "M16 2v4", "M3 10h18", "M8 2v4", "M17 14h-6", "M13 18H7", "M7 14h.01", "M17 18h.01",
    ]
    static let sprout = [
        "M14 9.536V7a4 4 0 0 1 4-4h1.5a.5.5 0 0 1 .5.5V5a4 4 0 0 1-4 4 4 4 0 0 0-4 4c0 2 1 3 1 5a5 5 0 0 1-1 3",
        "M4 9a5 5 0 0 1 8 4 5 5 0 0 1-8-4", "M5 21h14",
    ]
    static let bell = [
        "M10.268 21a2 2 0 0 0 3.464 0",
        "M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326",
    ]
    static let fileText = [
        "M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z",
        "M14 2v5a1 1 0 0 0 1 1h5", "M10 9H8", "M16 13H8", "M16 17H8",
    ]
    /// Material `Icons.Outlined.MoreHoriz` — 신고 메뉴
    static let moreHoriz = ["M6 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm12 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm-6 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"]
    /// Material `Icons.Filled.DoneAll` — 읽음
    static let doneAll = ["M18 7l-1.41-1.41-6.34 6.34 1.41 1.41L18 7zm4.24-1.41L11.66 16.17 7.48 12l-1.41 1.41L11.66 19l12-12-1.42-1.41zM.41 13.41L6 19l1.41-1.41L1.83 12 .41 13.41z"]
    /// Material `Icons.AutoMirrored.Filled.Send` — 보내기
    static let sendFilled = ["M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"]
    /// Material `Icons.Filled.Close`
    static let closeFilled = ["M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"]
    /// Material `Icons.Outlined.FileDownload`
    static let fileDownloadOutlined = ["M18 15v3H6v-3H4v3c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2v-3h-2zm-1-4l-1.41-1.41L13 12.17V4h-2v8.17L8.41 9.59 7 11l5 5 5-5z"]
    /// 프로필 메뉴 줄 — Material Outlined `FavoriteBorder` · `Block` · `MailOutline` · `Delete` · `Shield`
    static let favoriteBorder = ["M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-4.4 15.55l-.1.1-.1-.1C7.14 14.24 4 11.39 4 8.5 4 6.5 5.5 5 7.5 5c1.54 0 3.04.99 3.57 2.36h1.87C13.46 5.99 14.96 5 16.5 5c2 0 3.5 1.5 3.5 3.5 0 2.89-3.14 5.74-7.9 10.05z"]
    static let blockOutlined = ["M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zM4 12c0-4.42 3.58-8 8-8 1.85 0 3.55.63 4.9 1.69L5.69 16.9C4.63 15.55 4 13.85 4 12zm8 8c-1.85 0-3.55-.63-4.9-1.69L18.31 7.1C19.37 8.45 20 10.15 20 12c0 4.42-3.58 8-8 8z"]
    static let mailOutline = ["M20 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 14H4V8l8 5 8-5v10zm-8-7L4 6h16l-8 5z"]
    static let deleteOutlined = ["M16 9v10H8V9h8m-1.5-6h-5l-1 1H5v2h14V4h-3.5l-1-1zM18 7H6v12c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7z"]
    static let shieldOutlined = ["M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm7 10c0 4.52-2.98 8.69-7 9.93-4.02-1.24-7-5.41-7-9.93V6.3l7-3.11 7 3.11V11z"]
    /// Material `Icons.AutoMirrored.Filled.KeyboardArrowRight`
    static let keyboardArrowRight = ["M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z"]
    /// Material `Icons.AutoMirrored.Filled.Logout` · `Icons.Filled.Person`
    static let logout = ["M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"]
    static let personFilled = ["M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"]
}
