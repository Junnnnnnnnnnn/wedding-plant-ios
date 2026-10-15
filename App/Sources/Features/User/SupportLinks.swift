import SwiftUI
import UIKit
import WPNetworking

/// 프로필의 메뉴 줄 — 신랑 · 신부 · 차단 관리 · 문의하기 · 계정 및 데이터 삭제 안내 · 개인정보처리방침 ·
/// (광고 개인정보 설정) · 유료 서비스 이용약관. 안드로이드 `UserScreen.SupportLinks` 와 같은 순서·같은 줄.
///
/// **앱 안에서 연락할 방법이 이 줄 하나뿐이다.** 방침은 로그인 여부와 **무관하게 항상** 보여야 한다 —
/// 스토어 심사에서 앱 안 접근 경로를 본다. 차단 관리는 **푸는 곳**이라 빠지면 정책 위반이다.
///
/// **밑줄 두 개가 아니라 메뉴 줄이다**(시안 `docs/concepts/user-contact.html` 의 B안).
struct SupportLinks: View {
    /// 신랑·신부 시트. 로그인한 사람에게만 넘긴다(없으면 줄을 내지 않는다)
    var onOpenCouple: (() -> Void)?
    /// 메일 앱이 없어 주소를 복사했을 때 띄우는 안내.
    @State private var copiedNotice: String?
    @State private var blockListOpen = false
    @ObservedObject private var ads = AdsService.shared

    var body: some View {
        VStack(spacing: 0) {
            SupportRowLine()
            // 신랑 · 신부 — 홈의 초대 띠는 혼자일 때만 떠서, 둘이 된 뒤 해제·그만두기로 갈 길이 여기뿐이다.
            if let onOpenCouple {
                SupportRow(paths: WPIconPaths.favoriteBorder, label: "신랑 · 신부", sub: "초대하거나, 함께하기를 그만둘 수 있어요",
                           identifier: "user.couple", action: onOpenCouple)
            }
            SupportRow(paths: WPIconPaths.blockOutlined, label: "차단 관리", sub: "차단한 사람을 보고 풀 수 있어요",
                       identifier: "user.blocks") { blockListOpen = true }
            SupportRow(paths: WPIconPaths.mailOutline, label: "문의하기", sub: "막히거나 이상한 점을 알려 주세요",
                       identifier: "user.support", action: sendSupportMail)
            SupportRow(paths: WPIconPaths.deleteOutlined, label: "계정 및 데이터 삭제 안내", identifier: "user.deletion") {
                UIApplication.shared.open(AppLinks.webBase.appendingPathComponent("account-deletion"))
            }
            SupportRow(paths: WPIconPaths.shieldOutlined, label: "개인정보처리방침", identifier: "user.privacy") {
                UIApplication.shared.open(AppLinks.privacyPolicy)
            }
            // 광고 동의를 다시 고르는 줄 — 동의 메시지가 뜬 지역에서만(UMP 요구)
            if ads.privacyOptionsRequired {
                SupportRow(paths: WPIconPaths.shieldOutlined, label: "광고 개인정보 설정", sub: "맞춤 광고 동의를 다시 고를 수 있어요",
                           identifier: "user.adPrivacy") { Task { await ads.presentPrivacyOptions() } }
            }
            // 유료 약관은 **산 사람도 다시 볼 수 있어야** 한다. 바로 아래 로그아웃 묶음이 선을 긋고 있어 아랫선을 뺀다.
            SupportRow(paths: WPIconPaths.descriptionOutlined, label: "유료 서비스 이용약관", identifier: "user.terms", bottomLine: false) {
                UIApplication.shared.open(AppLinks.webBase.appendingPathComponent("terms"))
            }

            if let copiedNotice {
                Text(copiedNotice)
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.fgSubtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
        .sheet(isPresented: $blockListOpen) { BlockListSheet() }
    }

    /// 문의 메일. **본문에 버전·기기·iOS 버전을 미리 채운다** (`AppLinks.support`).
    private func sendSupportMail() {
        guard let url = AppLinks.support, UIApplication.shared.canOpenURL(url) else {
            // 메일 앱을 지운 기기가 있다. 주소를 복사해 두면 다른 데로 보낼 수 있다.
            UIPasteboard.general.string = AppConfig.supportEmail
            copiedNotice = "메일 앱이 없어 주소를 복사했어요 — \(AppConfig.supportEmail)"
            return
        }
        UIApplication.shared.open(url)
    }
}

/// 시안의 `.row` — 30pt 분홍 아이콘 타일 + 라벨(+보조 문구) + 오른쪽 화살표.
private struct SupportRow: View {
    var paths: [String]
    var label: String
    var sub: String?
    var identifier: String
    var bottomLine = true
    var action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 0) {
                    WPMaterialPathIcon(paths: paths, size: 16, color: WPColor.primary)
                        .frame(width: 30, height: 30)
                        .background(SupportPalette.tile, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label).wpTypography(14.5).foregroundStyle(WPColor.fgNeutral)
                        if let sub { Text(sub).wpTypography(12).foregroundStyle(SupportPalette.sub) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                    WPMaterialPathIcon(paths: WPIconPaths.keyboardArrowRight, size: 18, color: SupportPalette.chevron)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 15)
                // 줄 전체가 눌리는 자리다.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)

            if bottomLine { SupportRowLine() }
        }
    }
}

private struct SupportRowLine: View {
    var body: some View {
        Rectangle().fill(SupportPalette.line).frame(height: 1).frame(maxWidth: .infinity)
    }
}

/// 시안 `docs/concepts/user-contact.html` 의 `--line` · `.ic` · `--ink-3` · `.chev`(안드로이드도 같은 파일에 같은 네 값).
private enum SupportPalette {
    static let line = Color(hex: 0xECEFF3)
    static let tile = Color(hex: 0xFFF2F6)
    static let sub = Color(hex: 0x7A6C74)
    static let chevron = Color(hex: 0xCFC8CD)
}

// MARK: - 차단 관리

/// 차단 관리 — 차단한 사람을 보고 푸는 자리. 안드로이드 `ui/moderation/BlockListSheet.kt`(웹 `BlockListModal`).
///
/// 익명 피드에서 차단한 사람은 서버가 `"차단한 사용자"` 로 가려서 준다 — **`displayName` 을 그대로 쓰고
/// 보완하려 들지 않는다**(여기서 이름을 알려 주면 곧 익명을 푸는 통로다).
struct BlockListSheet: View {
    struct Blocked: Decodable, Sendable, Identifiable, Equatable {
        let id: Int
        let displayName: String
        let source: String?
    }
    @EnvironmentObject private var env: AppEnvironment
    @State private var list: [Blocked] = []
    @State private var loading = true
    @State private var busyId: Int?
    @State private var error: String?
    @State private var height: CGFloat = 240

    var body: some View {
        BlockListBody(list: list, loading: loading, busyId: busyId, error: error) { row in
            Task { await unblock(row) }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = ceil($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .wpBottomSheet(height: height, corner: 28)
        .task {
            do { list = try await env.api.send(HTTPRequest(path: "/plan/moderation/block/list")) }
            catch { self.error = "목록을 불러오지 못했어요." }
            loading = false
        }
    }

    private func unblock(_ row: Blocked) async {
        busyId = row.id
        do {
            try await env.api.sendIgnoringData(HTTPRequest(method: .delete, path: "/plan/moderation/block/\(row.id)"))
            list.removeAll { $0.id == row.id }
            env.moderationRevision += 1
        } catch { self.error = "차단을 풀지 못했어요." }
        busyId = nil
    }
}

/// 시트 본문 — 상태 없이 찍는다.
struct BlockListBody: View {
    var list: [BlockListSheet.Blocked]
    var loading: Bool
    var busyId: Int?
    var error: String?
    var onUnblock: (BlockListSheet.Blocked) -> Void = { _ in }
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("차단 관리").wpTypography(16, .bold).foregroundStyle(WPColor.fgNeutral)
            Color.clear.frame(height: 14)
            if loading {
                Text("불러오는 중...").wpTypography(13).foregroundStyle(WPColor.fgSubtle)
                    .frame(maxWidth: .infinity).frame(height: 90)
            } else if list.isEmpty {
                // 비었을 때도 **어디서 차단하는지** 적는다 — 여기까지 온 사람은 대개 "어떻게 하는 거지" 를 묻고 있다
                VStack(spacing: 0) {
                    WPEmptyIconCircle(paths: WPIconPaths.blockOutlined, background: WPColor.fill, tint: WPColor.fgSubtle, material: true)
                    Text("차단한 사람이 없어요.").wpTypography(13.5).foregroundStyle(WPColor.fgMuted).padding(.top, 12)
                    Text("후기나 자랑하기에서 글 옆의 ··· 을 누르면 신고하거나 차단할 수 있어요.").wpTypography(12.5, lineHeight: 18)
                        .foregroundStyle(WPColor.fgSubtle).multilineTextAlignment(.center).padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // **목록만 굴린다** — 많이 차단해도 아래 줄의 '차단 해제' 가 잘리지 않게
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(list) { row in BlockRow(row: row, busy: busyId == row.id) { onUnblock(row) } }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = ceil($0) }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(max(listHeight, 1), 520))
            }
            if let error {
                Text(error).wpTypography(12.5).foregroundStyle(WPColor.danger).padding(.top, 10)
            }
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 28)
    }
}

private struct BlockRow: View {
    var row: BlockListSheet.Blocked
    var busy: Bool
    var onUnblock: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName).wpTypography(14).foregroundStyle(WPColor.fgNeutral).lineLimit(1)
                Text("\(row.source?.uppercased() == "BRAG" ? "자랑하기" : "견적 후기")에서 차단").wpTypography(12).foregroundStyle(WPColor.fgSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onUnblock) {
                Text(busy ? "푸는 중..." : "차단 해제").wpTypography(12.5, .bold).foregroundStyle(WPColor.fgMuted)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .overlay(Capsule().stroke(WPColor.strokeWeak, lineWidth: 1))
            }
            .buttonStyle(.plain).disabled(busy)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(WPColor.strokeSubtle, lineWidth: 1))
    }
}
