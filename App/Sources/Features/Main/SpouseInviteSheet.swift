import SwiftUI
import WPDomain
import WPModels
import WPNetworking

/// 플랜 공유 시트 — 안드로이드 `ui/components/SharePlanSheet.kt`(웹 `SharePlanModal`) 이식.
///
/// ```
/// 흰 시트 · 위 모서리 32
/// [상단 그라데이션 바]  #ee2b8c -> #ff94a1
/// "플랜 공유하기" / "신랑 · 신부를 초대해 함께 준비해요"    [X]
/// [신랑 · 신부 두 사람이 함께 써요]  안내
/// 혜택 3개 (실시간 소통 / 일정 공유 / 함께 키우는 재미)
/// 우리 둘 상자 (방장은 해제, 신랑·신부는 그만두기)
/// [♥ 신랑 · 신부 초대하기]  그라데이션 버튼 / 각주
/// ```
///
/// 방에는 방장과 신랑·신부뿐이다. 초대는 늘 신랑·신부 링크(`?as=spouse`)다.
struct SpouseInviteSheet: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var invite: ShareCode?
    @State private var user: PlanUser?
    /// 내가 신랑·신부로 들어간 플랜의 방장 이름. nil 이면 귀속 아님, 빈 문자열이면 이름을 모름.
    @State private var boundOwner: String?
    @State private var loading = true
    @State private var saving = false
    @State private var share = false
    @State private var confirming = false
    @State private var message: String?
    @State private var height: CGFloat = 640

    private var couple: [Member] { (user?.members ?? []).filter { ["OWNER", "SPOUSE"].contains($0.permission.rawValue.uppercased()) } }
    private var hasSpouse: Bool { couple.contains { $0.permission.rawValue.uppercased() == "SPOUSE" } }
    private var isOwner: Bool { couple.contains { $0.planUserId == user?.id && $0.permission.rawValue.uppercased() == "OWNER" } }
    private var url: String? { invite.flatMap { ShareLink.inviteURL(webBaseURL: AppConfig.webBaseURL, code: $0.shareCode, asSpouse: true) } }

    var body: some View {
        VStack(spacing: 0) {
        // 6pt 그라데이션 바는 스크롤 밖 시트 꼭대기에 둔다 — 스크롤 안에서는 시트 위 여백에 가려 보이지 않았다
        SharePlanSheetBody.topBar
        ScrollView {
            SharePlanSheetBody(showsBar: false,
                couple: couple, myId: user?.id ?? "", boundOwner: boundOwner,
                canUnlink: boundOwner != nil || (isOwner && hasSpouse),
                confirming: confirming, saving: saving, loading: loading,
                full: hasSpouse || invite?.canInvite == false, message: message,
                onClose: { if !saving { dismiss() } },
                onAsk: { confirming = true }, onCancel: { confirming = false },
                onConfirm: { Task { await unlink() } },
                onShare: {
                    if url == nil { message = loading ? "준비 중입니다." : "링크를 불러오지 못했습니다." } else { share = true }
                }
            )
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = ceil($0) }
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        // 내용이 시트보다 길면 가운데 정렬로 위가 잘렸다 — 위에 붙인다
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .wpBottomSheet(height: height + 6, corner: 32)
        .interactiveDismissDisabled(saving)
        .task { await load() }
        .sheet(isPresented: $share) { if let url { ActivityShareSheet(items: ["우리 결혼 준비, 같이 하자!\n" + url]) } }
    }

    private func load() async {
        loading = true
        // 공유 시트의 부가 정보라 실패해도 링크 공유는 그대로 쓸 수 있다.
        if let value: PlanUser = try? await env.api.send(Endpoint.user()) { user = value }
        if let rooms: RoomList = try? await env.api.send(Endpoint.roomList()) {
            boundOwner = BoundRoom.find(in: rooms.list, planUserId: user?.id)?.ownerName.trimmingCharacters(in: .whitespaces)
        }
        do {
            let code: ShareCode = try await env.api.send(Endpoint.shareCode())
            invite = code
            if code.shareCode.trimmingCharacters(in: .whitespaces).isEmpty { message = "공유 코드를 받지 못했습니다." }
        } catch let error as APIError {
            // 401 은 "서버가 고장" 이 아니라 "로그인이 필요" 다.
            if case .http(let status, _) = error, status == 401 { message = "로그인하면 공유 링크를 만들 수 있어요." }
            else if case .unauthorized = error { message = "로그인하면 공유 링크를 만들 수 있어요." }
            else { message = "공유 링크를 만들지 못했습니다. 잠시 후 다시 시도해 주세요." }
        } catch { message = "공유 링크를 만들지 못했습니다. 잠시 후 다시 시도해 주세요." }
        loading = false
    }

    private func unlink() async {
        guard !saving else { return }
        let leaving = boundOwner != nil
        saving = true
        // 지난 실패 문구를 지운다 — 다시 해서 성공해도 남아 있었다
        message = nil
        do {
            try await env.api.sendIgnoringData(HTTPRequest(method: leaving ? .post : .delete, path: leaving ? "/plan/room/leave" : "/plan/room/spouse"))
        } catch {
            saving = false
            message = "변경에 실패했습니다. 잠시 후 다시 시도해 주세요."
            return
        }
        saving = false
        confirming = false
        env.boundRoom = .unknown; env.boundRoomPlan = nil
        await env.refreshBoundRoom(); env.roomsRevision += 1
        if leaving { dismiss() } else { await load() }
    }
}

/// 시트 본문 — **상태를 갖지 않는다**(스크린샷 테스트가 단계별로 그린다).
struct SharePlanSheetBody: View {
    /// 시트 맨 위 그라데이션 바(`#ee2b8c -> #ff94a1`, 6)
    static var topBar: some View {
        LinearGradient(colors: [WPColor.primary, WPColor.inviteBarEnd], startPoint: .leading, endPoint: .trailing).frame(height: 6)
    }
    var showsBar = true
    var couple: [Member]
    var myId: String
    var boundOwner: String?
    var canUnlink: Bool
    var confirming: Bool
    var saving: Bool
    var loading: Bool
    /// 이미 신랑·신부가 있거나 서버가 초대를 받지 않는다(`canInvite` false)
    var full: Bool
    var message: String?
    var onClose: () -> Void = {}
    var onAsk: () -> Void = {}
    var onCancel: () -> Void = {}
    var onConfirm: () -> Void = {}
    var onShare: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            if showsBar { Self.topBar }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("플랜 공유하기").tracking(-0.4).wpTypography(20, .black).foregroundStyle(WPColor.textPrimary)
                        Text("신랑 · 신부를 초대해 함께 준비해요").wpTypography(11, .bold).foregroundStyle(WPColor.gray400)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onClose) {
                        WPMaterialPathIcon(paths: WPIconPaths.closeFilled, size: 16, color: WPColor.gray400)
                            .frame(width: 36, height: 36).background(WPColor.gray50, in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("닫기")
                }
                .padding(.top, 32)

                // 안내 알약
                Text("신랑 · 신부 두 사람이 함께 써요").tracking(0.25).wpTypography(10, .bold).foregroundStyle(WPColor.primary)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(WPColor.primary.opacity(0.03), in: Capsule())
                    .overlay(Capsule().stroke(WPColor.primary.opacity(0.07), lineWidth: 1))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                VStack(spacing: 16) {
                    SharePlanBenefitRow(paths: WPIconPaths.messageCircle, gradient: [WPColor.primary, WPColor.invitePink], title: "실시간 소통",
                                       text: "실시간 채팅과 알림으로 파트너와 즉각적으로 소통하며 준비해요.")
                    SharePlanBenefitRow(paths: WPIconPaths.calendarRange, gradient: [WPColor.inviteIndigo, WPColor.inviteIndigoLight], title: "일정 공유",
                                       text: "복잡한 웨딩 스케줄을 하나의 캘린더로 함께 보고 꼼꼼하게 관리하세요.")
                    SharePlanBenefitRow(paths: WPIconPaths.sprout, gradient: [WPColor.inviteGreen, WPColor.inviteGreenLight], title: "함께 키우는 재미",
                                       text: "준비 단계에 따라 성장하는 우리만의 웨딩 플랜트를 함께 완성해보세요.")
                }
                .padding(.top, 24)

                // 우리 둘 — **초대 버튼 위**
                if !couple.isEmpty || boundOwner != nil {
                    CoupleSection(couple: couple, myId: myId, boundOwner: boundOwner, canUnlink: canUnlink, confirming: confirming,
                                  saving: saving, onAsk: onAsk, onCancel: onCancel, onConfirm: onConfirm)
                        .padding(.top, 24)
                }

                Color.clear.frame(height: 24)
                if let message {
                    HStack(spacing: 8) {
                        Circle().fill(WPColor.danger).frame(width: 6, height: 6)
                        Text(message).wpTypography(11, .bold).foregroundStyle(WPColor.danger)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(WPColor.dangerBg, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 12)
                }

                // 귀속된 사람에게는 초대 버튼을 내지 않는다 — 그 사람의 초대 링크는 화면에 없는 개인 플랜을 가리킨다.
                if boundOwner == nil {
                    let active = !full && !loading
                    Button(action: onShare) {
                        HStack(spacing: 12) {
                            WPSVGPath(paths: WPIconPaths.heart).fill(Color.white)
                                .overlay(WPSVGPath(paths: WPIconPaths.heart).stroke(Color.white, style: StrokeStyle(lineWidth: 20.0 / 12, lineCap: .round, lineJoin: .round)))
                                .frame(width: 20, height: 20)
                            Text(loading ? "준비 중..." : full ? "신랑 · 신부는 이미 있어요" : "신랑 · 신부 초대하기")
                                .wpTypography(16, .black).foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(LinearGradient(colors: [WPColor.primary, WPColor.invitePink], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 16))
                        .opacity(active ? 1 : 0.6)
                        .shadow(color: WPColor.primary.opacity(0.3), radius: 10, y: 6)
                    }
                    .buttonStyle(.plain).allowsHitTesting(active).accessibilityIdentifier("invite.spouse")
                    .padding(.bottom, 12)
                }
                Text("신랑 · 신부는 일정과 예산을 같이 보고 같이 고칠 수 있어요.".wpKeepAll).wpTypography(11.5, lineHeight: 19)
                    .foregroundStyle(WPColor.gray400).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.white)
    }
}

/// 혜택 한 줄 — 아이콘 카드 + 제목 + 설명(안드로이드 `BenefitRow`)
private struct SharePlanBenefitRow: View {
    var paths: [String]
    var gradient: [Color]
    var title: String
    var text: String

    var body: some View {
        HStack(spacing: 16) {
            WPLucideIcon(paths: paths, size: 24, color: .white, strokeWidth: 2.5)
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: gradient[0].opacity(0.35), radius: 6, y: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).wpTypography(16, .black, lineHeight: 16).foregroundStyle(WPColor.textPrimary)
                Text(text.wpKeepAll).wpTypography(11, .bold, lineHeight: 18).foregroundStyle(WPColor.gray400)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(WPColor.primary.opacity(0.012), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.gray50, lineWidth: 1))
    }
}

/// 우리 둘 — 방장에게는 신랑·신부 **해제**, 신랑·신부로 들어간 사람에게는 **함께하기 그만두기**.
/// 되돌릴 수 없어 한 번 더 묻는다(시스템 확인창이 아니라 상자 안에서 — 안드로이드와 같음). 상태 없이 찍는다.
struct CoupleSection: View {
    var couple: [Member]
    var myId: String
    var boundOwner: String?
    var canUnlink: Bool
    var confirming: Bool
    var saving: Bool
    var onAsk: () -> Void = {}
    var onCancel: () -> Void = {}
    var onConfirm: () -> Void = {}

    var body: some View {
        let leaving = boundOwner != nil
        VStack(alignment: .leading, spacing: 0) {
            Text(leaving ? "함께 쓰는 플랜" : "우리 둘").wpTypography(13, .black).foregroundStyle(WPColor.textPrimary)
                .padding(.bottom, 12)
            if leaving {
                let owner = boundOwner?.trimmingCharacters(in: .whitespaces) ?? ""
                Text((owner.isEmpty ? "신랑 · 신부로 함께 쓰는 플랜이 있어요." : "\(owner)님 플랜을 신랑 · 신부로 함께 쓰고 있어요.").wpKeepAll)
                    .wpTypography(12.5, lineHeight: 20).foregroundStyle(WPColor.passSheetMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(couple) { member in CoupleMemberRow(member: member, isMe: member.planUserId == myId) }
                }
            }
            if canUnlink {
                if confirming {
                    VStack(alignment: .leading, spacing: 10) {
                        Text((leaving ? "그만두면 이 플랜과 대화방에서 빠지고, 홈이 내 플랜으로 돌아가요. 주고받은 대화와 일정은 남아요."
                              : "해제하면 신랑 · 신부가 이 플랜과 대화방에서 빠져요. 주고받은 대화와 일정은 남고, 초대 링크는 새로 바뀌어요.").wpKeepAll)
                            .wpTypography(12, lineHeight: 19).foregroundStyle(WPColor.warnBody).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button(action: onCancel) {
                                Text("취소").wpTypography(12, .bold).foregroundStyle(WPColor.passSheetMuted)
                                    .frame(maxWidth: .infinity).frame(height: 36)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(WPColor.passCardStroke, lineWidth: 1))
                                    .opacity(saving ? 0.5 : 1)
                            }
                            .buttonStyle(.plain).allowsHitTesting(!saving)
                            Button(action: onConfirm) {
                                Text(saving ? "처리 중..." : leaving ? "그만두기" : "해제하기").wpTypography(12, .bold).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).frame(height: 36)
                                    .background(WPColor.textPrimary, in: RoundedRectangle(cornerRadius: 8))
                                    .opacity(saving ? 0.5 : 1)
                            }
                            .buttonStyle(.plain).allowsHitTesting(!saving).accessibilityIdentifier("couple.confirm")
                        }
                    }
                    .padding(12)
                    .background(WPColor.warnBg, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 12)
                } else {
                    Button(action: onAsk) {
                        Text(leaving ? "함께하기 그만두기" : "신랑 · 신부 해제하기").wpTypography(11.5, .bold).underline()
                            .foregroundStyle(WPColor.gray400).padding(.vertical, 4)
                    }
                    .buttonStyle(.plain).padding(.top, 12).accessibilityIdentifier("couple.unlink")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WPColor.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(WPColor.gray50, lineWidth: 1))
    }
}

private struct CoupleMemberRow: View {
    var member: Member
    var isMe: Bool
    var body: some View {
        let isSpouse = member.permission.rawValue.uppercased() == "SPOUSE"
        let initial = member.name.trimmingCharacters(in: .whitespaces).prefix(1)
        HStack(spacing: 0) {
            Text(initial.isEmpty ? "?" : String(initial)).wpTypography(12, .black).foregroundStyle(WPColor.primary)
                .frame(width: 32, height: 32).background(WPColor.primary.opacity(0.07), in: Circle())
            Text((member.name.trimmingCharacters(in: .whitespaces).isEmpty ? "이름 없음" : member.name) + (isMe ? " (나)" : ""))
                .wpTypography(13, .bold).foregroundStyle(WPColor.textPrimary).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
            if isSpouse {
                HStack(spacing: 4) {
                    WPSVGPath(paths: WPIconPaths.heart).fill(WPColor.primary)
                        .overlay(WPSVGPath(paths: WPIconPaths.heart).stroke(WPColor.primary, style: StrokeStyle(lineWidth: 10.0 / 12, lineCap: .round, lineJoin: .round)))
                        .frame(width: 10, height: 10)
                    Text("신랑 · 신부").wpTypography(11, .bold).foregroundStyle(WPColor.primary)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(WPColor.spouseBadgeBg, in: Capsule())
                .padding(.leading, 8)
            } else {
                Text("방장").wpTypography(11.5).foregroundStyle(WPColor.gray400).padding(.leading, 8)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 시스템 공유 시트.
struct ActivityShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete?(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
