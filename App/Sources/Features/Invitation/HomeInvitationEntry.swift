import SwiftUI
import WPDomain

/// 홈의 청첩장 입구 — 안드로이드 `ui/main/HomeInvitationEntry.kt` 와 같은 두 모양.
///
/// - **줄**(패스 없음, `rowOnly`): 예산 카드 안, 가는 선 아래 한 줄. 누르면 청첩장 첫 화면 — 결제로 바로 가지 않는다.
/// - **정원 카드**(빈 정원 · 내 청첩장): 머리 면 바로 아래. 카드 전체는 청첩장 첫 화면으로 가고,
///   빈 정원의 분홍 `만들기` 만 편집기를 바로 연다(구성 시트부터).
///
/// 무엇을 낼지는 `InvitationStore.homeState` 가 정하고 여기는 그리기만 한다. 글자 줄 높이는
/// 안드로이드 값(`lineHeight`)을 그대로 쓴다.
struct HomeInvitationEntry: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject var model: InvitationStore
    var rowOnly = false
    /// 빈 정원이 "미리 채워 둘게요" 로 말할 홈의 결혼식 날짜(`YYYY-MM-DD`) · 예식장 — 청첩장이 붙는 방과 같은 방
    var planDate: String? = nil
    var planVenue: String? = nil
    @State private var creating = false

    var body: some View {
        Group {
            switch model.homeState {
            case .loading, .error: EmptyView()
            case .landing:
                if rowOnly { row }
            case .empty, .mine:
                if !rowOnly { gardenCard }
            }
        }
    }

    // MARK: - 줄 (패스 없음)

    private var row: some View {
        NavigationLink { InvitationStudioView() } label: {
            VStack(spacing: 0) {
                HomeInviteColor.line.frame(height: 1).padding(.horizontal, 20)
                HStack(spacing: 0) {
                    EnvelopeTile()
                    Spacer().frame(width: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(InvitationRules.homeRowTitle)
                            .wpTypography(14, .bold, lineHeight: 20)
                            .foregroundStyle(WPColor.textPrimary)
                        Text(InvitationRules.homeRowNote.wpKeepAll)
                            .wpTypography(12, lineHeight: 17)
                            .foregroundStyle(HomeInviteColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(InvitationRules.homeRowNote)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(width: 10)
                    Text(InvitationRules.homeRowAction)
                        .font(WPFont.hak(12.5, .bold))
                        .foregroundStyle(WPColor.brand700)
                        .lineLimit(1)
                        .fixedSize()
                    WPLucideIcon(paths: WPIconPaths.chevronRight, size: 18, color: HomeInviteColor.chevron)
                        .padding(.leading, 2)
                }
                .padding(.leading, 20)
                .padding(.trailing, 16)
                .padding(.top, 13)
                .padding(.bottom, 15)
            }
            .background(Color.white)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("main.invitationRow")
    }

    // MARK: - 정원 카드 (패스 있음)

    private var gardenCard: some View {
        let empty = model.homeState == .empty
        let invitation = model.result?.invitation
        let published = invitation?.published == true
        let guestbookOn = invitation.map {
            InvitationRules.normalize($0.design).sections.contains { $0.type == "guestbook" && $0.visible }
        } ?? false
        let latest = InvitationRules.homeLatestWish(model.wishes.map { (name: $0.name, message: $0.message, createdAt: $0.createdAt) })
        let text = empty
            ? InvitationRules.homeEmptyText(planDate: planDate, planVenue: planVenue)
            : InvitationRules.homeMineText(published: published, guestbookOn: guestbookOn, guests: model.total, fresh: model.fresh, latest: latest)
        // 아래 줄이 하객이 쓴 글이면 한 줄로 자른다 — 우리 문장은 어절로 꺾는다
        let wishNote = !empty && published && guestbookOn && (model.total ?? 0) > 0 && latest != nil
        let groom = (invitation?.groom).flatMap { $0.isEmpty ? nil : $0 } ?? "신랑"
        let bride = (invitation?.bride).flatMap { $0.isEmpty ? nil : $0 } ?? "신부"
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        return NavigationLink { InvitationStudioView() } label: {
                VStack(alignment: .leading, spacing: 0) {
                    SeasideGardenView(
                        wishes: model.wishes,
                        empty: empty,
                        peek: true,
                        groom: groom,
                        bride: bride,
                        labelNote: empty ? nil : InvitationRules.mineLabelNote(published: published, guests: model.total),
                        emptySeats: !empty && model.wishes.isEmpty
                            && InvitationRules.mineEmptySeats(published: published, guestbookOn: guestbookOn, guests: model.total)
                    )
                    .aspectRatio(2, contentMode: .fit)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.32)
                    .allowsHitTesting(false)
                    .clipped()
                    .id(empty ? "empty" : "mine")

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(text.title.wpKeepAll)
                                .wpTypography(14, .bold, lineHeight: 20)
                                .foregroundStyle(WPColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                // 어절 줄바꿈 글자(U+2060)를 읽거나 찾지 않게 원문을 이름으로 둔다
                                .accessibilityLabel(text.title)
                            if wishNote {
                                Text(text.note)
                                    .wpTypography(12, lineHeight: 17)
                                    .foregroundStyle(HomeInviteColor.muted)
                                    .lineLimit(1)
                            } else {
                                Text(text.note.wpKeepAll)
                                    .wpTypography(12, lineHeight: 17)
                                    .foregroundStyle(HomeInviteColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityLabel(text.note)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 단추 자리 — 빈 정원의 `만들기` 는 카드와 다른 곳(편집기)으로 가서, 버튼을 겹치지 않게
                        // 카드 **밖**에 같은 자리로 얹는다(아래 `overlayPreferenceValue`).
                        actionPill(text.action, primary: empty)
                            .opacity(empty ? 0 : 1)
                            .anchorPreference(key: CreatePillAnchorKey.self, value: .bounds) { $0 }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 13)
                }
                .background(Color.white)
                .clipShape(shape)
                .overlay(shape.strokeBorder(HomeInviteColor.cardStroke, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("main.invitationGarden")
        .overlayPreferenceValue(CreatePillAnchorKey.self) { anchor in
            GeometryReader { geometry in
                if empty, let anchor {
                    let rect = geometry[anchor]
                    Button { creating = true } label: { actionPill(text.action, primary: true) }
                        .buttonStyle(.plain)
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityIdentifier("main.invitationCreate")
                }
            }
        }
        .shadow(color: HomeInviteColor.shadow, radius: 4, y: 2)
        .fullScreenCover(isPresented: $creating, onDismiss: { Task { await model.load(env) } }) {
            InvitationEditorView(saved: nil, roomId: model.result?.roomId, initialFocus: "layout", planDate: planDate, planVenue: planVenue)
        }
    }

    /// 안드로이드 `ActionPill` — 12.5 굵게 · 줄 18 · 좌우 14 위아래 7
    private func actionPill(_ label: String, primary: Bool) -> some View {
        Text(label)
            .wpTypography(12.5, .bold, lineHeight: 18)
            .foregroundStyle(primary ? Color.white : WPColor.brand700)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(primary ? WPColor.primary : WPColor.brand100, in: Capsule())
    }
}

private struct CreatePillAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
}

/// 분홍 칸 안의 봉투 — 안드로이드 `EnvelopeTile`(38 · 모서리 12 · `#fff1f7`, lucide Mail 20)
private struct EnvelopeTile: View {
    var body: some View {
        WPLucideIcon(paths: HomeInviteColor.mail, size: 20, color: WPColor.primary)
            .frame(width: 38, height: 38)
            .background(WPColor.brand100, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 안드로이드 `WpColors.HomeBudget*` · `HomeInvite*` 값(홈 화면에서만 쓴다)
enum HomeInviteColor {
    static let muted = Color(hex: 0x7A6C74)
    static let chevron = Color(hex: 0xA79BA3)
    static let line = Color(hex: 0xF2EAEE)
    /// `0x12EE2B8C`
    static let cardStroke = Color(hex: 0xEE2B8C).opacity(Double(0x12) / 255)
    /// `0x401B0D14`
    static let shadow = Color(hex: 0x1B0D14).opacity(Double(0x40) / 255 * 0.35)
    /// lucide Mail
    static let mail = [
        "m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7",
        "M4 4h16a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z",
    ]
}
