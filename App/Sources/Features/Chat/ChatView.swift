import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/chat/[chatRoomId]/page.tsx` 이식.
///
/// ```
/// [<] 방 이름 / 멤버 이름들                    [⋯]
/// ── 날짜 구분선 ──
/// 아바타 [말풍선]                    [내 말풍선] 시각
/// [사진] [ 입력창 ] [보내기]
/// ```
///
/// - Note: 웹은 `fixed inset-0` 로 화면을 통째로 덮는다. 그래서 하단 탭바 위에
///   전체 화면으로 띄운다(참여 플랜에서 `fullScreenCover`).
struct ChatView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var push: PushService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var model: ChatViewModel
    @State private var showRenameSheet = false
    @State private var openSchedule: ScheduleRef?
    @FocusState private var inputFocused: Bool

    init(chatRoomId: Int) {
        _model = StateObject(wrappedValue: ChatViewModel(chatRoomId: chatRoomId))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if model.loading {
                LoadingBody()
            } else {
                messages
            }

            inputBar
        }
        .background(Color.white)
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
            if phase == .active { model.onForeground() }
        }
        // 웹은 `/schedule-detail?id=...` 로 이동한다. 채팅은 전체 화면이라 커버로 띄운다.
        .fullScreenCover(item: $openSchedule) { schedule in
            ScheduleDetailView(scheduleId: schedule.id)
                .environmentObject(env)
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameChatRoomSheet(currentName: model.roomName) { name in
                showRenameSheet = false
                Task { await model.rename(to: name, env: env) }
            } onCancel: {
                showRenameSheet = false
            }
        }
        .alert("알림", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("세션이 만료되었습니다. 다시 로그인해 주세요.", isPresented: $model.sessionExpired) {
            Button("확인", role: .cancel) { dismiss() }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(WPColor.stone600)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로가기")
            .accessibilityIdentifier("chat.back")

            VStack(alignment: .leading, spacing: 2) {
                Text(model.roomName)
                    .font(WPFont.hak(20))
                    .tracking(WPFont.trackingTight(20))
                    .foregroundStyle(WPColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // 잠깐 끊길 때 빨간 배너 대신 여기에만 표시한다 (자동 재연결이 도는 중이다).
                Text(model.connected || env.isDemo ? model.memberNames : "연결 중...")
                    .font(WPFont.hak(10, .medium))
                    .foregroundStyle(WPColor.stone400)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            Button { showRenameSheet = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(WPColor.stone400)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("채팅방 설정")
            .accessibilityIdentifier("chat.menu")
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WPColor.gray100).frame(height: 1)
        }
    }

    // MARK: - 메시지

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    if model.loadingMore {
                        ProgressView()
                            .tint(WPColor.primary)
                            .frame(height: 40)
                    } else if model.hasMore {
                        // 위쪽 끝이 보이면 이전 페이지를 불러온다 (웹의 scrollTop <= 50 대응).
                        Color.clear
                            .frame(height: 1)
                            .onAppear { Task { await model.loadMore(env: env) } }
                    }

                    ForEach(Array(model.lines.enumerated()), id: \.element.id) { index, line in
                        VStack(spacing: 24) {
                            if ChatTimeline.showsDateHeader(model.lines, at: index) {
                                DateDivider(text: ChatTimeline.dateHeaderText(line.dayKey))
                            }
                            MessageRow(
                                line: line,
                                showsSenderName: ChatTimeline.showsSenderName(model.lines, at: index)
                            ) { scheduleId in
                                openSchedule = ScheduleRef(id: scheduleId)
                            }
                        }
                        .id(line.id)
                    }

                    // 항상 아래로 붙이기 위한 표식
                    Color.clear.frame(height: 1).id(Self.bottomAnchor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .accessibilityIdentifier("chat.scroll")
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.lines.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: model.loading) { _, loading in
                if !loading { scrollToBottom(proxy) }
            }
            .onChange(of: inputFocused) { _, focused in
                if focused { scrollToBottom(proxy) }
            }
        }
    }

    private static let bottomAnchor = "chat.bottom"

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        // 렌더가 끝난 뒤에 내려야 마지막 줄이 잘리지 않는다.
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        }
    }

    // MARK: - 입력

    private var inputBar: some View {
        HStack(spacing: 8) {
            // 사진 첨부는 웹도 아직 동작하지 않는다. 자리만 맞춰 둔다.
            Image(systemName: "photo")
                .font(.system(size: 18))
                .foregroundStyle(WPColor.stone400)
                .frame(width: 44, height: 44)
                .background(WPColor.gray50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            TextField("메시지를 입력하세요...", text: $model.input, axis: .vertical)
                .font(WPFont.tmoney(16))
                .foregroundStyle(WPColor.stone800)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .background(WPColor.gray50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("chat.input")

            Button {
                model.send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(model.canSend ? .white : WPColor.gray400)
                    .frame(width: 44, height: 44)
                    .background(
                        model.canSend ? WPColor.primary : WPColor.gray200,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(
                        color: model.canSend ? WPColor.primary.opacity(Double(0x44) / 255) : .clear,
                        radius: 8,
                        y: 4
                    )
            }
            .buttonStyle(.plain)
            .disabled(!model.canSend)
            .accessibilityLabel("보내기")
            .accessibilityIdentifier("chat.send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle().fill(WPColor.gray100).frame(height: 1)
        }
    }
}

// MARK: - 부품

private struct LoadingBody: View {
    var body: some View {
        VStack(spacing: 24) {
            ForEach(0..<4, id: \.self) { index in
                HStack {
                    if index.isMultiple(of: 2) {
                        Circle().fill(WPColor.gray100).frame(width: 32, height: 32)
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(WPColor.gray100)
                            .frame(width: 192, height: 48)
                        Spacer(minLength: 0)
                    } else {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(WPColor.gray100)
                            .frame(width: 192, height: 48)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DateDivider: View {
    var text: String

    var body: some View {
        Text(text)
            .font(WPFont.hak(10, .bold))
            // 웹 `tracking-widest` (= 0.1em)
            .tracking(1)
            .foregroundStyle(WPColor.gray400)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(WPColor.stone100.opacity(0.8), in: Capsule())
            .frame(maxWidth: .infinity)
    }
}

/// `fullScreenCover(item:)` 은 Identifiable 을 요구한다.
private struct ScheduleRef: Identifiable, Hashable {
    var id: Int
}

private struct MessageRow: View {
    var line: ChatLine
    var showsSenderName: Bool
    var onOpenSchedule: (Int) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if line.isMine {
                Spacer(minLength: 40)
                TimeStamp(line: line)
                bubbleColumn
            } else {
                Avatar()
                bubbleColumn
                TimeStamp(line: line)
                Spacer(minLength: 40)
            }
        }
    }

    private var bubbleColumn: some View {
        VStack(alignment: line.isMine ? .trailing : .leading, spacing: 4) {
            if showsSenderName {
                Text(line.senderName)
                    .font(WPFont.hak(10, .bold))
                    .foregroundStyle(WPColor.gray400)
                    .padding(.leading, 4)
            }
            Bubble(line: line, onOpenSchedule: onOpenSchedule)
        }
    }
}

private struct Avatar: View {
    var body: some View {
        // 웹: 프로필 이미지가 없으면 회색 원 안에 사람 아이콘
        Image(systemName: "person.fill")
            .font(.system(size: 18))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Color(hex: 0xE2E8F0), in: Circle())
    }
}

private struct TimeStamp: View {
    var line: ChatLine

    var body: some View {
        VStack(spacing: 2) {
            // 내가 보낸 메시지를 모두가 읽으면 체크 두 개
            if line.isMine && line.unreadCount == 0 {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WPColor.primary)
            }
            Text(line.timeText)
                .font(WPFont.hak(9, .bold))
                .foregroundStyle(WPColor.gray300)
        }
        .frame(width: 52)
    }
}

private struct Bubble: View {
    var line: ChatLine
    var onOpenSchedule: (Int) -> Void

    var body: some View {
        if line.messageType == "schedule", let schedule = line.schedule {
            ScheduleCard(schedule: schedule, onOpen: onOpenSchedule)
        } else if line.messageType == "schedule" {
            Text("삭제된 일정입니다.")
                .font(WPFont.hak(14))
                .foregroundStyle(WPColor.gray400)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(WPColor.gray100, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            // 사용자가 입력한 값이라 Tmoney (웹 `font-tmoney`)
            Text(line.text ?? "")
                .font(WPFont.tmoney(14))
                .lineSpacing(4)
                .foregroundStyle(line.isMine ? .white : WPColor.stone800)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    line.isMine ? WPColor.primary : Color.white,
                    in: bubbleShape(isMine: line.isMine)
                )
                .overlay {
                    if !line.isMine {
                        bubbleShape(isMine: false).stroke(WPColor.gray100, lineWidth: 1)
                    }
                }
                .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
        }
    }
}

/// 웹 `rounded-[20px]` + 보낸 쪽 모서리 하나만 각지게 (`rounded-tr-none` / `rounded-tl-none`).
private func bubbleShape(isMine: Bool) -> UnevenRoundedRectangle {
    let radius: CGFloat = 20
    return UnevenRoundedRectangle(
        topLeadingRadius: isMine ? radius : 0,
        bottomLeadingRadius: radius,
        bottomTrailingRadius: radius,
        topTrailingRadius: isMine ? 0 : radius,
        style: .continuous
    )
}

private struct ScheduleCard: View {
    var schedule: ChatSchedule
    var onOpen: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(schedule.title)
                .font(WPFont.hak(13, .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(
                    LinearGradient(
                        colors: [WPColor.primary, Color(hex: 0xFF6B9D)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                Text(schedule.categoryName)
                    .font(WPFont.hak(11, .medium))
                    .foregroundStyle(WPColor.gray500)

                if let startDate = schedule.startDate,
                   let date = KstDate(dateString: startDate) {
                    Spacer().frame(height: 6)
                    Text(verbatim: "\(date.year)년 \(date.month)월 \(date.day)일")
                        .font(WPFont.hak(12))
                        .foregroundStyle(WPColor.gray500)
                }

                if let location = schedule.location, !location.isEmpty {
                    Spacer().frame(height: 4)
                    // 이모지는 웹 원문 그대로다.
                    Text("📍 \(location)")
                        .font(WPFont.hak(12))
                        .foregroundStyle(WPColor.gray500)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer().frame(height: 8)
                Rectangle().fill(WPColor.gray200.opacity(0.6)).frame(height: 1)
                Spacer().frame(height: 8)

                HStack {
                    Text("비용")
                        .font(WPFont.hak(11, .medium))
                        .foregroundStyle(WPColor.gray400)
                    Spacer()
                    Text(amountText)
                        .font(WPFont.hak(16, .black))
                        .foregroundStyle(WPColor.primary)
                }

                if schedule.id > 0 {
                    Spacer().frame(height: 12)
                    Button { onOpen(schedule.id) } label: {
                        HStack(spacing: 4) {
                            Text("상세보기")
                                .font(WPFont.hak(12, .bold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(WPColor.gray600)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Color.white.opacity(0.8),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(WPColor.gray200, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chat.schedule.\(schedule.id)")
                }
            }
            .padding(16)
        }
        .frame(minWidth: 220, maxWidth: 280, alignment: .leading)
        .background(WPColor.gray50)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
    }

    private var amountText: String {
        let amount = schedule.amount ?? 0
        return amount > 0 ? "\(wpThousands(amount))만원" : "미정"
    }
}

// MARK: - 이름 변경

private struct RenameChatRoomSheet: View {
    var currentName: String
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("채팅방 이름 변경")
                .font(WPFont.hak(18, .bold))
                .foregroundStyle(WPColor.textPrimary)

            Spacer().frame(height: 20)

            TextField("채팅방 이름", text: $name)
                .font(WPFont.tmoney(16))
                .foregroundStyle(WPColor.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(WPColor.stone50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("chat.rename.input")

            Spacer().frame(height: 20)

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("취소")
                        .font(WPFont.hak(15, .bold))
                        .foregroundStyle(WPColor.stone600)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(WPColor.stone100, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { onSave(name) } label: {
                    Text("저장")
                        .font(WPFont.hak(15, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("chat.rename.save")
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .presentationDetents([.height(236)])
        .presentationCornerRadius(32)
        .onAppear { name = currentName }
    }
}
