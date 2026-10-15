import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 채팅 탭의 대화 — 안드로이드 `ui/chat/ChatScreen.kt`(웹 `ChatRoomView` `variant="standalone"`) 이식.
///
/// ```
/// [나][상대]  상대이름                [⋯]
///             결혼식까지 N일 · M월 D일
/// 날짜 구분선
/// 상대 말: 얼굴 + (이어 말하면 이름 생략) + 말풍선(왼쪽) + 시각 · ⋯(신고)
///        ( + ) 현우님이 일정을 추가했어요 · 제목   보기     ← 활동 줄(가운데)
/// 내 말: 말풍선(오른쪽, 분홍) + 읽음 · 시각
/// [+] [현우에게 메시지] [보내기]
/// ```
///
/// - 방 이름·이름 바꾸기·멤버 목록은 없다(안드로이드와 같음) — 대화가 하나뿐이라 누구와 이야기하는지만 말한다.
/// - `⋯` 는 신랑·신부 해제·그만두기(공유 시트)를 연다.
/// - 멤버가 아닌 방은 까닭만 말하고 입력창을 내지 않는다.
struct ChatView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var push: PushService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var model: ChatViewModel
    @State private var openSchedule: ScheduleRef?
    /// 탭 셸 위에 일정 상세를 연다(탭바가 남음 — Android `SCHEDULE_DETAIL`). 셸 밖이면 예전처럼 전체 화면.
    @Environment(\.scheduleDetailPresenter) private var detailPresenter
    @FocusState private var inputFocused: Bool

    var standalone = false
    var planRoomId: Int?
    var weddingDate: String?
    var partnerName: String?
    @State private var showCouple = false
    @State private var showPlanPicker = false
    @State private var reportMessage: Int?

    init(chatRoomId: Int, standalone: Bool = false, planRoomId: Int? = nil, weddingDate: String? = nil, partnerName: String? = nil) {
        self.standalone = standalone; self.planRoomId = planRoomId; self.weddingDate = weddingDate; self.partnerName = partnerName
        _model = StateObject(wrappedValue: ChatViewModel(chatRoomId: chatRoomId, planRoomId: planRoomId))
    }

    /// 나·상대 — 대화방 정보의 멤버로 가른다(안드로이드 `members.firstOrNull`)
    private var me: Member? { model.members.first { $0.planUserId == model.myPlanUserId } }
    private var partner: Member? { model.members.first { $0.planUserId != model.myPlanUserId } }
    private var partnerTitle: String? {
        let name = partner?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }
    private var loadFailed: Bool { !model.historyLoaded && model.lines.isEmpty && model.errorMessage != nil }

    private func openDetail(_ id: Int) {
        let opened = detailPresenter?.open(ScheduleDetailRequest(scheduleId: id, roomId: model.planRoomId)) ?? false
        if !opened { openSchedule = ScheduleRef(id: id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.loading {
                // 받는 동안은 머리까지 뼈대(안드로이드 `ChatLoadingSkeleton`)
                ChatLoadingSkeleton()
            } else {
                ChatPartnerHeader(
                    me: me, partner: partner,
                    title: partnerTitle ?? "대화",
                    subtitle: CoupleChatRules.describeWeddingDay(weddingDate) ?? "우리 둘의 대화",
                    onOpenCouple: model.notMember ? nil : { showCouple = true }
                )
                if model.notMember {
                    ChatNotMemberNotice()
                } else {
                    if loadFailed {
                        ChatLoadFailed { Task { await model.load(env: env); await model.loadActivities(env: env) } }
                    } else {
                        messages
                    }
                    if let message = model.errorMessage, !loadFailed {
                        InfoBanner(message: message, actionLabel: "닫기") { model.errorMessage = nil }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    inputBar
                }
            }
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showCouple) { SpouseInviteSheet() }
        .sheet(isPresented: $showPlanPicker) { PickPlanSheet(roomId: model.planRoomId, model: model) }
        .sheet(isPresented: Binding(get: { reportMessage != nil }, set: { if !$0 { reportMessage = nil } })) {
            if let id = reportMessage { ReportContentSheet(targetType: "CHAT_MESSAGE", targetId: id, onHidden: {}) }
        }
        .task { await model.start(env: env) }
        .onAppear {
            // 이 방을 보고 있는 동안에는 이 방 알림을 띄우지 않는다 (소켓으로 이미 화면에 뜬다).
            push.currentChatRoomId = model.chatRoomId
        }
        .onDisappear {
            model.leave()
            if push.currentChatRoomId == model.chatRoomId {
                push.currentChatRoomId = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // 백그라운드에 오래 있다 돌아오면 소켓이 죽어 있을 수 있다.
            if phase == .active { model.onForeground(); Task { await model.loadActivities(env: env) } }
        }
        .fullScreenCover(item: $openSchedule) { schedule in
            ScheduleDetailView(scheduleId: schedule.id, roomId: model.planRoomId)
                .environmentObject(env)
        }
        .alert("세션이 만료되었습니다. 다시 로그인해 주세요.", isPresented: $model.sessionExpired) {
            Button("확인", role: .cancel) { dismiss() }
        }
    }

    // MARK: - 메시지

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.loadingMore {
                        ProgressView().tint(WPColor.primary).frame(maxWidth: .infinity).padding(8)
                    } else if model.hasMore {
                        // 위쪽 끝이 보이면 이전 페이지를 불러온다.
                        Color.clear.frame(height: 1).onAppear { Task { await model.loadMore(env: env) } }
                    }

                    let items = ChatActivityRules.merge(messages: model.lines, activities: model.activities, hasMore: model.hasMore)
                    ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                        let previous = offset > 0 ? items[offset - 1] : nil
                        let showDate = previous?.dayKey != item.dayKey
                        VStack(spacing: 0) {
                            if showDate { ChatDateDivider(text: ChatTimeline.dateHeaderText(item.dayKey)) }
                            switch item {
                            case .activity(let activity):
                                ChatActivityRow(activity: activity) { openDetail($0) }
                            case .message(let line, _):
                                // 상대 이름 줄은 이어 말하면 뺀다 — 앞 줄이 같은 사람의 말이고 날짜가 같을 때만.
                                // 활동 줄 다음 말에는 다시 단다(안드로이드 `showName`).
                                let prevSender: String? = { if case let .message(p, _) = previous { return p.senderId }; return nil }()
                                ChatMessageRow(
                                    line: line,
                                    showName: previous == nil || prevSender != line.senderId || showDate,
                                    onOpenSchedule: { openDetail($0) },
                                    onReport: { if let id = Int(line.id) { reportMessage = id } }
                                )
                            }
                            Color.clear.frame(height: 12)
                        }.id(item.id)
                    }

                    // 항상 아래로 붙이기 위한 표식
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .padding(16)
            }
            .background(WPColor.background)
            .accessibilityIdentifier("chat.scroll")
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.lines.last?.id) { _, _ in scrollToBottom(proxy) }
            .onChange(of: model.loading) { _, loading in if !loading { scrollToBottom(proxy, animated: false) } }
            .onChange(of: inputFocused) { _, focused in if focused { scrollToBottom(proxy) } }
            .onAppear { scrollToBottom(proxy, animated: false) }
        }
    }

    private static let bottomAnchor = "chat.bottom"

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        // 렌더가 끝난 뒤에 내려야 마지막 줄이 잘리지 않는다.
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
            } else {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        }
    }

    // MARK: - 입력

    private var inputBar: some View {
        let enabled = model.connected
        let placeholder = partnerTitle.map { "\($0)에게 메시지" } ?? "메시지 입력"
        let canSend = model.canSend
        return HStack(spacing: 8) {
            // 플랜 올리기 — 보내기와 같이 **붙어 있을 때만** 켠다(끊긴 사이 고른 플랜이 두 번 올라갔다)
            Button { showPlanPicker = true } label: {
                WPLucideIcon(paths: WPIconPaths.lucidePlus, size: 20, color: enabled ? WPColor.stone400 : WPColor.gray300)
                    .frame(width: 44, height: 44)
                    .background(WPColor.gray50, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain).allowsHitTesting(enabled)
            .accessibilityLabel("플랜 공유하기").accessibilityIdentifier("chat.pickPlan")

            TextField("", text: $model.input, prompt: Text(placeholder).foregroundColor(WPColor.gray400), axis: .vertical)
                .font(Font(WPTypeface.tmoney.uiFont(15, .regular)))
                .foregroundStyle(WPColor.textPrimary)
                .tint(WPColor.primary)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(WPColor.gray50, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(WPColor.gray100, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 22))
                .onTapGesture { inputFocused = true }
                .accessibilityIdentifier("chat.input")

            Button { model.send() } label: {
                WPMaterialPathIcon(paths: WPIconPaths.sendFilled, size: 20, color: .white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? WPColor.primary : WPColor.gray200, in: Circle())
            }
            .buttonStyle(.plain).allowsHitTesting(canSend)
            .accessibilityLabel("보내기").accessibilityIdentifier("chat.send")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.white)
    }
}

// MARK: - 머리

/// 채팅 머리 — 안드로이드 `ChatPartnerHeader`. 분홍 면 최소 64, 아래 모서리 22, 좌우 16, 칸 사이 12.
/// 나·상대 얼굴(32, 8 겹침, 바깥 2 링 `#f43d93`) · 상대 이름(18 굵게) · 부제(12.5, 흰 85%) · `⋯`(36).
struct ChatPartnerHeader: View {
    var me: Member?
    var partner: Member?
    var title: String
    var subtitle: String
    /// nil 이면 `⋯` 를 내지 않는다(멤버가 아닌 방)
    var onOpenCouple: (() -> Void)?

    var body: some View {
        BrandHead(corner: 22, horizontal: 16, top: 6, bottom: 6) {
            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    ChatHeaderAvatar(member: me, mine: true)
                    if partner != nil { ChatHeaderAvatar(member: partner, mine: false).offset(x: 24) }
                }
                .frame(width: partner != nil ? 56 : 32, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).tracking(-0.36).wpTypography(18, .bold, face: .kakao, lineHeight: 22.5).lineLimit(1)
                    Text(subtitle).wpTypography(12.5, face: .kakao).opacity(0.85).lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                if let onOpenCouple {
                    Button(action: onOpenCouple) {
                        WPLucideIcon(paths: WPIconPaths.ellipsisVertical, size: 20, color: .white)
                            .frame(width: 36, height: 36).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("신랑 · 신부 관리").accessibilityIdentifier("chat.couple")
                }
            }
            .frame(minHeight: 52)
        }
    }
}

/// 머리의 얼굴 — 나는 흰 바탕 분홍 글자, 상대는 보라 바탕 흰 글자. 사진이 있으면 사진.
private struct ChatHeaderAvatar: View {
    var member: Member?
    var mine: Bool
    var body: some View {
        let name = member?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let initial = String((name.isEmpty ? (mine ? "나" : "?") : name).prefix(1))
        ZStack {
            Circle().fill(mine ? Color.white : WPColor.chatPartnerAvatar)
            if let image = member?.image, !image.isEmpty, let url = URL(string: image) {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
            } else {
                Text(initial).font(Font(WPTypeface.kakao.uiFont(13, .bold))).foregroundStyle(mine ? WPColor.primary : .white)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        // 자리를 차지하지 않는 바깥 2 링 — 상대 얼굴이 내 얼굴 위에 겹쳐 경계가 된다
        .background(Circle().fill(WPColor.chatHeaderRing).padding(-2))
    }
}

// MARK: - 상태

/// 대화를 받는 동안의 뼈대 — 안드로이드 `ChatLoadingSkeleton`.
private struct ChatLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            BrandHead(corner: 22, horizontal: 16, top: 0, bottom: 0) {
                HStack(spacing: 4) {
                    HStack(spacing: -8) {
                        SkeletonBox(width: 32, height: 32, onBrand: true, corner: 16)
                        SkeletonBox(width: 32, height: 32, onBrand: true, corner: 16)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBox(width: 96, height: 16, onBrand: true)
                        SkeletonBox(width: 144, height: 10, onBrand: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 64)
            }
            VStack(spacing: 24) {
                ForEach(1...4, id: \.self) { i in
                    let left = i % 2 != 0
                    HStack(alignment: .bottom, spacing: 8) {
                        if left { SkeletonBox(width: 32, height: 32, corner: 16) } else { Spacer(minLength: 0) }
                        SkeletonBox(width: 192, height: 48, corner: 16)
                        if left { Spacer(minLength: 0) }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 32)
            .frame(maxHeight: .infinity)
            Rectangle().fill(WPColor.gray100).frame(height: 1)
            SkeletonBox(height: 44, corner: 16).padding(16)
        }
        .background(Color.white)
    }
}

/// 기록을 못 받았을 때 — 안드로이드 `ChatLoadFailed`.
private struct ChatLoadFailed: View {
    var onRetry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("대화를 불러오지 못했습니다.\n네트워크 상태를 확인한 뒤 다시 시도해 주세요.")
                .wpTypography(14, face: .kakao, lineHeight: 21).foregroundStyle(WPColor.stone500).multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text("다시 시도").font(Font(WPTypeface.kakao.uiFont(14, .bold))).foregroundStyle(.white)
                    .padding(.horizontal, 24).frame(height: 44).background(WPColor.primary, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 64).padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

/// 멤버가 아닌 대화방의 안내 — 흰 바탕 위쪽에 회색 한 줄(안드로이드 `ChatNotMemberNotice`).
struct ChatNotMemberNotice: View {
    var body: some View {
        Text(ChatViewModel.notMemberMessage).wpTypography(14, face: .kakao).foregroundStyle(WPColor.stone500)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 64)
            .background(Color.white)
    }
}

// MARK: - 부품

private struct ChatDateDivider: View {
    var text: String
    var body: some View {
        Text(text).font(Font(WPTypeface.kakao.uiFont(11, .bold))).foregroundStyle(WPColor.gray400)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(WPColor.gray100, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
}

/// 대화 속 활동 줄 — 안드로이드 `ActivityRow`. 가운데, 12.5 `#7a6c74`, 이름만 굵게 `#4a3d44`,
/// 앞 점 18(`#fff1f7`, 분홍 + 또는 체크 11), 끝에 `보기`(`#cc1873`, 일정일 때만).
private struct ChatActivityRow: View {
    var activity: PlanActivity
    var onOpenSchedule: (Int) -> Void
    var body: some View {
        let done = activity.type == "SCHEDULE_COMPLETED"
        let rawName = activity.actorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = rawName.isEmpty ? "누군가" : rawName
        let sentence = ChatActivityRules.sentence(activity)
        let rest = String(sentence.dropFirst(name.count))
        HStack(spacing: 6) {
            WPLucideIcon(paths: done ? WPIconPaths.lucideCheck : WPIconPaths.lucidePlus, size: 11, color: WPColor.primary, strokeWidth: 3)
                .frame(width: 18, height: 18).background(WPColor.brand100, in: Circle())
            (Text(name).font(Font(WPTypeface.kakao.uiFont(12.5, .bold))).foregroundColor(WPColor.chatActivityName)
                + Text(Self.keepAll(rest, title: activity.targetTitle)).foregroundColor(WPColor.chatShareSub))
                .wpTypography(12.5, face: .kakao, lineHeight: 17)
                .fixedSize(horizontal: false, vertical: true)
            if let target = activity.targetId {
                Button { onOpenSchedule(target) } label: {
                    Text("보기").font(Font(WPTypeface.kakao.uiFont(12.5, .bold))).foregroundStyle(WPColor.brand700).fixedSize()
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
    }

    /// 우리가 붙인 말은 어절로 꺾고, 일정 제목(사용자가 적은 값)은 그대로 둔다.
    private static func keepAll(_ rest: String, title: String?) -> String {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
              let range = rest.range(of: " · " + title) else { return rest.wpKeepAll }
        return String(rest[..<range.lowerBound]).wpKeepAll + " · " + title + String(rest[range.upperBound...]).wpKeepAll
    }
}

/// `fullScreenCover(item:)` 은 Identifiable 을 요구한다.
private struct ScheduleRef: Identifiable, Hashable {
    var id: Int
}

/// 말 한 줄 — 안드로이드 `MessageRow`.
private struct ChatMessageRow: View {
    var line: ChatLine
    var showName: Bool
    var onOpenSchedule: (Int) -> Void
    var onReport: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if line.isMine {
                Spacer(minLength: 0)
            } else {
                MemberAvatar(name: line.senderName, index: 0, size: 32)
                Color.clear.frame(width: 8, height: 1)
            }
            ChatBubbleWidth(maxWidth: 260) { VStack(alignment: line.isMine ? .trailing : .leading, spacing: 0) {
                if !line.isMine && showName {
                    Text(line.senderName).font(Font(WPTypeface.kakao.uiFont(11, .bold))).foregroundStyle(WPColor.gray500)
                        .padding(.bottom, 4)
                }
                if line.messageType == "schedule", let schedule = line.schedule {
                    ChatScheduleCard(schedule: schedule) { onOpenSchedule(schedule.id) }
                } else {
                    Text(line.text ?? "")
                        .wpTypography(15, face: .tmoney, lineHeight: 21)
                        .foregroundStyle(line.isMine ? .white : WPColor.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(line.isMine ? WPColor.primary : Color.white, in: UnevenRoundedRectangle(
                            topLeadingRadius: 16, bottomLeadingRadius: line.isMine ? 16 : 4,
                            bottomTrailingRadius: line.isMine ? 4 : 16, topTrailingRadius: 16))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } }
            .layoutPriority(1)
            Color.clear.frame(width: 6, height: 1)
            // 읽음은 시각 **옆**에 붙는다. 다 읽었으면 옅은 회색 체크.
            HStack(spacing: 4) {
                if line.isMine && line.unreadCount == 0 {
                    WPMaterialPathIcon(paths: WPIconPaths.doneAll, size: 12, color: Color(hex: 0xC9CCD2)).accessibilityLabel("읽음")
                } else if line.unreadCount > 0 {
                    Text("\(line.unreadCount)").font(Font(WPTypeface.kakao.uiFont(10, .bold))).foregroundStyle(WPColor.primary)
                }
                Text(line.timeText).font(Font(WPTypeface.kakao.uiFont(9, .bold))).foregroundStyle(WPColor.gray300)
                    .lineLimit(1).fixedSize()
                // 남의 말에만 신고(차단은 없음 — 보기 싫으면 방을 나가는 것이 맞다)
                if !line.isMine, Int(line.id) != nil {
                    Button(action: onReport) {
                        WPMaterialPathIcon(paths: WPIconPaths.moreHoriz, size: 17, color: WPColor.fgSubtle)
                            .frame(width: 28, height: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("신고하기")
                }
            }
            .padding(.bottom, 4)
            if !line.isMine { Spacer(minLength: 0) }
        }
    }
}

/// 말풍선 칸 — 남은 폭 안에서 **내용만큼** 차지하되 최대 폭을 넘지 않는다(안드로이드 `widthIn(max = 260.dp)`).
/// `.frame(maxWidth:)` 는 제안받은 폭까지 늘어나 시각이 말풍선에서 떨어졌다.
private struct ChatBubbleWidth: Layout {
    var maxWidth: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.map { min($0, maxWidth) } ?? maxWidth
        return subviews.first?.sizeThatFits(ProposedViewSize(width: width, height: proposal.height)) ?? .zero
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

/// 플랜 공유 메시지 — 흰 카드 + 테두리 한 줄(안드로이드 `ScheduleCard`).
private struct ChatScheduleCard: View {
    var schedule: ChatSchedule
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(schedule.categoryName).font(Font(WPTypeface.kakao.uiFont(12, .bold))).foregroundStyle(WPColor.brand700)
            Text(schedule.title).wpTypography(16, .bold, face: .kakao).foregroundStyle(WPColor.fgNeutral)
                .lineLimit(2).padding(.top, 2)
            Text(dateLine).wpTypography(13, face: .kakao).foregroundStyle(WPColor.fgMuted).padding(.top, 6)
            Rectangle().fill(WPColor.strokeSubtle).frame(height: 1).padding(.top, 12)
            HStack {
                Text("비용").wpTypography(12, face: .kakao).foregroundStyle(WPColor.fgSubtle)
                Spacer()
                Text(amountText).wpTypography(16, .bold, face: .kakao).foregroundStyle(WPColor.primary)
            }
            .padding(.top, 10)
            Button(action: onOpen) {
                Text("상세보기").wpTypography(13, .bold, face: .kakao).foregroundStyle(WPColor.fgMuted)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain).padding(.top, 12)
            .accessibilityIdentifier("chat.schedule.\(schedule.id)")
        }
        .padding(14)
        .frame(minWidth: 220, maxWidth: 280, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0x0F000000), lineWidth: 1))
    }

    private var dateLine: String {
        var text = schedule.startDate.flatMap { KstDate(dateString: $0) }.map { "\($0.year)년 \($0.month)월 \($0.day)일" } ?? "날짜 미정"
        if let location = schedule.location, !location.trimmingCharacters(in: .whitespaces).isEmpty { text += " · " + location }
        return text
    }

    private var amountText: String {
        let amount = schedule.amount ?? 0
        return amount > 0 ? "\(wpThousands(amount))만 원" : "미정"
    }
}
