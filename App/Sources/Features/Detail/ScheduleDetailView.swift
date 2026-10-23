import SwiftUI
import UIKit
import WPDomain
import WPModels
import WPUtils
import WPNetworking

/// 일정 상세 — 안드로이드 `ui/detail/ScheduleDetailScreen.kt` 와 **같은 구성·치수**.
///
/// 분홍 머리 면(카테고리 · 상태 알약 · 제목 · 날짜 · 금액 상자) → 장소 · 메모 · 서류 · 추가 카테고리 카드 →
/// 완료 토글 → 보내기 · 공유 카드(채팅 · 피드) → `삭제 · 수정하기` 한 줄(안드로이드 CLAUDE.md
/// "일정 상세 아래는 보내기 · 공유 카드 + 삭제 · 수정하기 한 줄", 시안 B안).
///
/// 안드로이드와 다른 점: 장소 카드 위의 카카오 지도는 **iOS 에 카카오맵 SDK 를 아직 붙이지 않아** 없다
/// (장소명과 "카카오맵에서 보기" 줄까지만).
struct ScheduleDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var guest: GuestStore
    @Environment(\.dismiss) private var systemDismiss
    /// 탭 셸이 덮어 그린 상세면 셸이 닫습니다(창이 아니라 `dismiss` 가 닿지 않음)
    @Environment(\.scheduleDetailClose) private var closeOverride
    @Environment(\.openURL) private var openURL

    private func dismiss() {
        if let closeOverride { closeOverride() } else { systemDismiss() }
    }

    @StateObject private var model: ScheduleDetailViewModel
    @State private var showDeleteConfirm = false
    @State private var showEdit = false
    /// 탭 셸 위에 플랜 추가·수정을 연다(탭바가 남음 — Android `ADD_PLAN`). 셸 밖·다른 창 위면 예전처럼 전체 화면.
    @Environment(\.addPlanPresenter) private var addPlanPresenter
    @State private var showFeed = false
    @State private var showChatShare = false
    /// 머리 면이 위로 지나갔는지 — 안드로이드 `headAway`(scroll > 260px). 지나가면 상태바 뒤에 흰 띠를 깐다.
    @State private var headAway = false

    init(scheduleId: Int, roomId: Int? = nil) {
        _model = StateObject(wrappedValue: ScheduleDetailViewModel(scheduleId: scheduleId, roomId: roomId))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.white

            if model.loading {
                DetailLoadingSkeleton()
            } else if let detail = model.detail {
                ScrollView {
                    content(detail)
                }
                .accessibilityIdentifier("detail.scroll")

                // 안드로이드 `BrandStatusBar` — 머리 면이 지나간 뒤 상태바 뒤의 흰 띠
                if headAway {
                    BrandStatusStrip()
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Button { dismiss() } label: {
                        WPMaterialPathIcon(paths: WPIconPaths.arrowBack, size: 20, color: WPColor.fgNeutral)
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("뒤로가기")
                    .accessibilityIdentifier("detail.back")
                    ErrorCard(message: model.errorMessage) {
                        Task { await model.load(env: env, guest: guest) }
                    } onHome: {
                        dismiss()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, wpStatusBarHeight)
                .padding(24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task { await model.load(env: env, guest: guest) }
        .sheet(isPresented: $showChatShare) { ShareScheduleSheet(scheduleId: model.scheduleId, title: model.detail?.title ?? "") }
        .sheet(isPresented: $showFeed) {
            FeedPostSheet(initialScheduleId: model.scheduleId, onPosted: {
                // 올렸으면 목록에서 빠진다 — 다시 받으면 피드 줄이 접힌다(안드로이드와 같음)
                showFeed = false
                Task { await model.loadPostables(env: env) }
            })
        }
        .fullScreenCover(isPresented: $showEdit) {
            // 수정은 추가와 같은 화면이다. editId 만 넘기면 상세를 불러와 채운다.
            AddPlanView(editId: model.scheduleId, roomId: model.roomId) {
                Task { await model.load(env: env, guest: guest) }
            }
            .environmentObject(env)
            .environmentObject(guest)
        }
        .fullScreenCover(isPresented: $model.deleted) {
            PlanBloomSuccess(title: model.detail?.title ?? "", amount: model.detail?.amount ?? 0, remaining: nil, action: .delete) {
                model.deleted = false; dismiss()
            }
        }
        .onChange(of: model.sessionExpired) { _, expired in
            if expired { dismiss() }
        }
        // overlay 로 띄우면 딤이 하단 탭바를 덮지 못한다. 탭바는 이 화면의 형제 뷰라
        // 화면 안쪽 overlay 범위 밖이기 때문이다. 배경이 투명한 전체 화면으로 올린다.
        .fullScreenCover(isPresented: $showDeleteConfirm) {
            DeleteConfirmDialog(deleting: model.deleting) {
                showDeleteConfirm = false
            } onConfirm: {
                showDeleteConfirm = false
                Task { await model.delete(env: env, guest: guest) }
            }
            .presentationBackground(.clear)
        }
    }

    @ViewBuilder
    private func content(_ detail: ScheduleDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailHead(detail: detail) { dismiss() }
                // 안드로이드는 `scroll.value > 260`(px, 밀도 2.625 → 약 99pt) 에서 띠를 깐다
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { headAway = $0 < -99 }
            Spacer().frame(height: 20)

            // 피드에 올리기는 맨 위 카드가 아니라 아래 보내기 · 공유 카드에 있다(안드로이드 2026-10-13)
            LocationCard(detail: detail) { openURL($0) }
            if let memo = detail.memo, !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MemoCard(memo: memo)
            }

            // 서류와 수정 권한은 지금 보고 있는 플랜의 멤버 권한을 따른다. 상세는 보기만(붙이고 지우기는 수정하기에서).
            if model.scheduleId > 0 && model.canSeeDocuments {
                PassDocumentsView(scheduleId: model.scheduleId)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
            }

            let extras = detail.addCategoryNameList.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !extras.isEmpty { ExtraCategoriesCard(categories: extras) }

            // 완료로 바꾸는 자리 — 웹·안드로이드와 같이 로그인한 경우에만.
            if !model.isGuest && model.canWrite {
                Spacer().frame(height: 24)
                StatusToggle(completed: detail.isCompleted, pending: model.statusPending) {
                    Task { await model.toggleStatus(env: env) }
                }
            }

            if !model.isGuest {
                ShareCard(couple: model.couple, feed: model.feedShare) {
                    showChatShare = true
                } onFeed: {
                    showFeed = true
                }
            }

            // 웹 `gap-2` + `mt-2`
            if model.canWrite {
                Spacer().frame(height: model.isGuest ? 16 : 8)
                ActionButtons(deleting: model.deleting) {
                    let opened = addPlanPresenter?.open(AddPlanRequest(editId: model.scheduleId, roomId: model.roomId) {
                        Task { await model.load(env: env, guest: guest) }
                    }) ?? false
                    if !opened { showEdit = true }
                } onDelete: {
                    showDeleteConfirm = true
                }
            }

            if !model.isGuest, model.canWrite, model.errorMessage == nil {
                InlineBannerAd(placement: "schedule", horizontal: 24, top: 40, bottom: 8)
            }
            if let message = model.errorMessage {
                InfoBanner(message: message, actionLabel: "닫기") {
                    model.errorMessage = nil
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .padding(.bottom, 24)
    }
}

// MARK: - 머리 면

/// 안드로이드 `Head` — 웹 면 `rounded-b-[24px] px-6 pb-5 pt-4`
private struct DetailHead: View {
    var detail: ScheduleDetail
    var onBack: () -> Void

    var body: some View {
        BrandHead(corner: 24, horizontal: 24, top: 16, bottom: 20) {
            HStack(spacing: 0) {
                Button(action: onBack) {
                    WPMaterialPathIcon(paths: WPIconPaths.arrowBack, size: 20, color: .white)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")
                .accessibilityIdentifier("detail.back")
                .offset(x: -8)

                // 웹 `truncate` — 사용자가 만든 이름이라 어절 묶기 없이 말줄임
                Text(detail.categoryName)
                    .wpTypography(18, .bold)
                    .tracking(-0.36)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer().frame(width: 8)
                StatusPill(detail: detail).fixedSize()
                Spacer(minLength: 0)
            }

            Spacer().frame(height: 12)
            DetailTmoneyLabel(text: detail.title, size: 28, lineHeight: 32, bold: true,
                              color: .white, tracking: -0.84)
                .accessibilityIdentifier("detail.title")

            Spacer().frame(height: 8)
            Text(dateText)
                .wpTypography(14)
                .foregroundStyle(.white.opacity(0.8))

            Spacer().frame(height: 16)
            // 시안 `.c-inset` — 금액과 결제 방식이 한 상자에 든다.
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("지출 금액").wpTypography(12).foregroundStyle(.white.opacity(0.8))
                    Spacer().frame(height: 2)
                    Text(verbatim: amountText).wpTypography(20, .bold).foregroundStyle(.white)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("결제 방식").wpTypography(12).foregroundStyle(.white.opacity(0.8))
                    Spacer().frame(height: 2)
                    Text(detail.payTypeLabel).wpTypography(14, .bold).foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var dateText: String {
        var text = detail.startDate.flatMap { KstDate(dateString: $0) }?.weddingDateText ?? "일정 미정"
        let time = formatKoreanTime(detail.startTime)
        if !time.isEmpty { text += " · " + time }
        return text
    }

    private var amountText: String {
        guard let amount = detail.amount else { return "미정" }
        return "\(wpThousands(amount))만 원"
    }
}

/// 웹 `rounded-full bg-white/15 px-2.5 py-1 text-[12px] font-bold whitespace-nowrap`
///
/// 결제가 일정 완료와 **어긋날 때만** 상태 글자 뒤에 붙인다 — `예정 · 결제함`(미리 낸 계약금).
private struct StatusPill: View {
    var detail: ScheduleDetail

    var body: some View {
        HStack(spacing: 6) {
            if detail.isCompleted {
                WPMaterialPathIcon(paths: WPIconPaths.check, size: 12, color: .white)
            } else {
                Circle().fill(Color.white).frame(width: 6, height: 6)
            }
            Text(label)
                .wpTypography(12, .bold)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("detail.statusPill")
    }

    private var label: String {
        (detail.isCompleted ? "완료" : "예정") + (detail.paymentMismatch.map { " · \($0.label)" } ?? "")
    }
}

/// Tmoney + 안드로이드 합성 볼드를 여러 줄로. `WPTmoneyText` 는 한 줄 전용이라 제목·장소가 길면 잘린다.
private struct DetailTmoneyLabel: UIViewRepresentable {
    let text: String
    var size: CGFloat
    var lineHeight: CGFloat
    var bold = false
    var color: Color
    var tracking: CGFloat = 0

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = attributed
        label.accessibilityLabel = text
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let rect = attributed.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                           options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let lines = max(1, Int((rect.height / lineHeight).rounded()))
        return CGSize(width: width, height: CGFloat(lines) * lineHeight)
    }

    private var attributed: NSAttributedString {
        let font = WPTypeface.tmoney.uiFont(size, .regular)
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.lineBreakMode = .byWordWrapping
        let ui = UIColor(color)
        return NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: ui, .strokeColor: ui, .strokeWidth: bold ? -2.5 : 0,
            .kern: tracking, .paragraphStyle: style,
            .baselineOffset: (lineHeight - font.lineHeight) / 4,
        ])
    }
}

// MARK: - 카드

/// 안드로이드 `DetailCard` — 옆 24 · 아래 18, 둥글기 24, 흰 면 + `DetailBorder` 1 + 그림자 1dp
private struct DetailCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(WPColor.detailBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.10), radius: 1.5, x: 0, y: 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
    }
}

/// 안드로이드 `DetailLabel` — 분홍 아이콘 14 + 6 + `12/18 #7D727A`
private struct DetailLabel: View {
    var icon: [String]
    var label: String

    var body: some View {
        HStack(spacing: 6) {
            WPMaterialPathIcon(paths: icon, size: 14, color: WPColor.primary)
            Text(label).wpTypography(12, lineHeight: 18).foregroundStyle(WPColor.detailLabel)
        }
    }
}

private struct LocationCard: View {
    var detail: ScheduleDetail
    var onOpenMap: (URL) -> Void

    var body: some View {
        DetailCard {
          VStack(alignment: .leading, spacing: 0) {
            // Android `LocationRow` — 좌표가 있으면 카드 맨 위에 카카오맵 200
            if detail.hasCoordinates, let lat = detail.locationLat, let lng = detail.locationLng,
               let location = detail.location, !location.trimmingCharacters(in: .whitespaces).isEmpty {
                KakaoMapView(latitude: lat, longitude: lng).frame(height: 200)
                    .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 0) {
                DetailLabel(icon: WPIconPaths.locationOnOutlined, label: "장소")
                Spacer().frame(height: 6)
                DetailTmoneyLabel(text: locationText, size: 16, lineHeight: 26, bold: true, color: WPColor.fgNeutral)
                if let url = detail.kakaoMapURL {
                    Spacer().frame(height: 14)
                    Rectangle().fill(WPColor.detailBorder).frame(height: 1)
                    Button { onOpenMap(url) } label: {
                        Text("카카오맵에서 보기  ↗")
                            .wpTypography(12.5, .bold)
                            .foregroundStyle(WPColor.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
          }
        }
    }

    private var locationText: String {
        guard let location = detail.location, !location.trimmingCharacters(in: .whitespaces).isEmpty else { return "장소 미정" }
        return location
    }
}

private struct MemoCard: View {
    var memo: String

    var body: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 0) {
                DetailLabel(icon: WPIconPaths.descriptionOutlined, label: "메모")
                Spacer().frame(height: 12)
                Text(memo)
                    .wpTypography(14, face: .tmoney, lineHeight: 25)
                    .foregroundStyle(WPColor.fgNeutral)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
    }
}

private struct ExtraCategoriesCard: View {
    var categories: [String]

    var body: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("추가 카테고리").wpTypography(14).foregroundStyle(WPColor.gray500)
                Spacer().frame(height: 12)
                // 개수가 많아지면 줄바꿈되어야 한다.
                FlowRow(spacing: 8, lineSpacing: 8) {
                    ForEach(categories, id: \.self) { name in
                        Text(name)
                            .wpTypography(14, .bold)
                            .foregroundStyle(WPColor.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(WPColor.extraChipBg, in: Capsule())
                            .overlay(Capsule().strokeBorder(WPColor.primary.opacity(0.07), lineWidth: 1))
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - 완료 토글

/// 안드로이드 `StatusToggle` — 웹 `rounded-xl bg-[#f7f8f9] px-4 py-3.5` + 24 원 체크
private struct StatusToggle: View {
    var completed: Bool
    var pending: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                ZStack {
                    Circle().fill(completed ? WPColor.positive : Color.white)
                    Circle().strokeBorder(completed ? WPColor.positive : WPColor.strokeWeak, lineWidth: 1.5)
                    if completed {
                        WPMaterialPathIcon(paths: WPIconPaths.check, size: 14, color: .white)
                    }
                }
                .frame(width: 24, height: 24)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(completed ? "예정으로 되돌리기" : "완료로 표시")
                        .wpTypography(16, .bold)
                        .foregroundStyle(WPColor.fgNeutral)
                    Spacer().frame(height: 2)
                    // 완료한 플랜은 결제한 것이다(`isPaid`, 안드로이드 2026-10-10)
                    Text(completed ? "아직 안 끝난 일이면 되돌릴 수 있어요" : "끝난 일이면 눌러 주세요 · 결제한 것으로 잡혀요")
                        .wpTypography(12)
                        .foregroundStyle(WPColor.fgSubtle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(pending ? 0.6 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pending)
        .accessibilityIdentifier("detail.status")
        .padding(.horizontal, 24)
    }
}

// MARK: - 보내기 · 공유

/// 안드로이드 `ShareCard` — 보내기 · 공유를 설명이 붙은 카드 한 장으로(시안 B안).
///
/// 피드 공유는 **익명으로 남에게 보이는 일**이라 버튼 글자 하나로 두지 않고 무엇이 어디로 가는지 한 줄을 붙인다.
private struct ShareCard: View {
    var couple: CoupleChatState
    var feed: ScheduleDetailViewModel.FeedShare
    var onChat: () -> Void
    var onFeed: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ShareRow(icon: WPIconPaths.messageCircle, iconTint: WPColor.fgMuted, tile: WPColor.fill,
                     title: "채팅으로 보내기", subtitle: chatSubtitle, enabled: true,
                     identifier: "detail.shareChat", onTap: onChat)
            if feed != .hidden {
                Rectangle().fill(WPColor.detailBorder).frame(height: 1)
                ShareRow(icon: WPIconPaths.star, iconTint: WPColor.primary, tile: WPColor.spouseBadgeBg,
                         title: "피드에 공유하기",
                         subtitle: (feed == .locked
                                    ? "내가 만든 플랜은 완료하면 올릴 수 있어요"
                                    : "익명 후기로 올라가요 · 다음 사람이 견적을 가늠해요").wpKeepAll,
                         enabled: feed == .ready, locked: feed == .locked,
                         identifier: "detail.shareFeed", onTap: onFeed)
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(WPColor.detailBorder, lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    /// 상대 이름은 사용자가 적은 값이라 어절로 묶지 않고, 붙는 우리 문장만 묶는다(안드로이드와 같음).
    private var chatSubtitle: String {
        switch couple {
        case .ready(_, _, _, let partnerName):
            return (partnerName ?? "신랑·신부") + "에게 이 플랜을 보내요".wpKeepAll
        case .solo:
            // 혼자인 사람에게는 "보내요" 라고 하지 않는다(시트가 "아직 함께 준비하는 사람이 없어요" 라고 한다)
            return "신랑 · 신부를 초대하면 보낼 수 있어요".wpKeepAll
        case .unavailable, .loading, .error:
            return "신랑 · 신부와의 대화로 보내요".wpKeepAll
        }
    }
}

private struct ShareRow: View {
    var icon: [String]
    var iconTint: Color
    var tile: Color
    var title: String
    var subtitle: String
    var enabled: Bool
    var locked = false
    var identifier: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tile)
                    WPLucideIcon(paths: icon, size: 16, color: iconTint)
                }
                .frame(width: 36, height: 36)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title.wpKeepAll).wpTypography(14.5, .bold).foregroundStyle(WPColor.textPrimary)
                    Spacer().frame(height: 2)
                    Text(subtitle).wpTypography(12, lineHeight: 17).foregroundStyle(WPColor.gray400)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 12)
                // 잠긴 줄은 화살표 대신 자물쇠 — 눌러도 아무 일이 없다는 표시
                WPLucideIcon(paths: locked ? WPIconPaths.lock : WPIconPaths.chevronRight, size: 16, color: WPColor.chevronFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .opacity(enabled ? 1 : 0.42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - 삭제 · 수정

/// 안드로이드 `ActionButtons` — 삭제 1 : 수정 2 한 줄(시안 B안). 삭제는 확인 창이 한 번 더 막는다.
private struct ActionButtons: View {
    var deleting: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        GeometryReader { g in
            let unit = (g.size.width - 8) / 3
            HStack(spacing: 8) {
                Button(action: onDelete) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(WPColor.fill)
                        // 1/3 칸이라 `삭제 중...` 은 큰 글꼴에서 넘친다 — 지우는 동안은 같은 자리에 도는 표시
                        if deleting {
                            ProgressView().tint(WPColor.fgMuted).frame(width: 18, height: 18)
                                .accessibilityLabel("삭제 중")
                        } else {
                            Text("삭제").wpTypography(16, .bold).foregroundStyle(WPColor.fgMuted).lineLimit(1)
                        }
                    }
                    .frame(width: unit, height: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(deleting)
                .accessibilityLabel("삭제하기")
                .accessibilityIdentifier("detail.delete")

                Button(action: onEdit) {
                    Text("수정하기")
                        .wpTypography(16, .bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: unit * 2, height: 56)
                        .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("detail.edit")
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 24)
    }
}

// MARK: - 받는 동안

/// 안드로이드 `LoadingSkeleton` — 전역 스피너 대신 머리 면 모양 그대로
private struct DetailLoadingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandHead(corner: 24, horizontal: 24, top: 16, bottom: 20) {
                SkeletonBox(width: 120, height: 24, onBrand: true)
                Spacer().frame(height: 16)
                SkeletonBox(width: 200, height: 32, onBrand: true)
                Spacer().frame(height: 10)
                SkeletonBox(width: 180, height: 16, onBrand: true)
                Spacer().frame(height: 16)
                SkeletonBox(width: nil, height: 64, onBrand: true, corner: 12)
            }
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { g in SkeletonBox(width: g.size.width / 2, height: 18) }.frame(height: 18)
                Spacer().frame(height: 12)
                SkeletonBox(width: nil, height: 160, corner: 12)
            }
            .padding(24)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 삭제 확인

/// 웹 main 의 삭제 확인 다이얼로그 이식.
///
/// **취소가 왼쪽, 삭제가 오른쪽**이다. 순서를 바꾸지 말 것 — 기본 다이얼로그는
/// 확인 버튼이 오른쪽에 좁게 붙어, 실제로 취소 대신 삭제를 눌러 플랜을 날린 적이 있다.
private struct DeleteConfirmDialog: View {
    var deleting: Bool
    var onDismiss: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // 줄 높이 1.5(Android 기본) — `.font` 만 쓰면 제목·부제 사이가 Android 보다 좁았다
                Text("이 플랜을 삭제할까요?")
                    .wpTypography(18, .bold)
                    .foregroundStyle(WPColor.textPrimary)

                Spacer().frame(height: 8)

                Text("삭제하면 되돌릴 수 없습니다.")
                    .wpTypography(14)
                    .foregroundStyle(WPColor.gray500)

                Spacer().frame(height: 20)

                HStack(spacing: 8) {
                    Button(action: onDismiss) {
                        Text("취소")
                            .wpTypography(14, .bold)
                            .foregroundStyle(WPColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(WPColor.gray200, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text(deleting ? "삭제 중..." : "삭제하기")
                            .wpTypography(14, .bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                WPColor.primary.opacity(deleting ? 0.6 : 1),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting)
                    .accessibilityIdentifier("detail.confirmDelete")
                }
            }
            .padding(24)
            .frame(maxWidth: 384)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)
        }
    }
}


private struct ErrorCard: View {
    var message: String?
    var onRetry: () -> Void
    var onHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("플랜을 찾을 수 없어요")
                .font(WPFont.hak(18, .semibold))
                .foregroundStyle(WPColor.primary)

            Spacer().frame(height: 8)

            Text(message ?? "")
                .font(WPFont.hak(14))
                .foregroundStyle(WPColor.stone500)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 16)

            HStack(spacing: 12) {
                Button(action: onHome) {
                    Text("돌아가기")
                        .font(WPFont.hak(14, .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(WPColor.primary, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onRetry) {
                    Text("다시 시도")
                        .font(WPFont.hak(14, .semibold))
                        .foregroundStyle(WPColor.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(WPColor.primary, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.top, 40)
    }
}
