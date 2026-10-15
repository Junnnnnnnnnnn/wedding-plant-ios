import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 후기 상세 — 안드로이드 `ui/feed/FeedDetailScreen.kt`(웹 `app/feed/FeedDetailView.tsx` 시안 A2) 이식.
///
/// 짜임은 **지도 머리 → 머리글 → 회색 금액 카드(시세 자 포함) → 후기 → 투표 → 바닥 담기**다.
/// 예전 iOS 는 분홍 머리 면에 제목을 얹어 안드로이드와 다른 화면이었다.
///
/// ## 백엔드에 단건 조회가 없다
/// 목록이 받아 둔 항목을 그대로 넘긴다 — `NavigationStack` 이 값을 실어 나른다.
///
/// ## 지도
/// **좌표가 없으면 지도 블록을 통째로 내지 않는다** — 정보가 없는데 168pt 를 먹는다.
/// 안드로이드는 카카오 지도 SDK 를 쓰지만 iOS 에는 그 SDK 를 붙이지 않아 같은 자리·크기에
/// 카카오맵(Android 와 같은 SDK)을 둔다. 길 찾기는 `카카오맵에서 열기` 로 넘긴다(안드로이드와 같은 링크).
struct FeedDetailView: View {
    var post: FeedPost
    /// 투표를 바꾸면 목록에도 같은 값이 보이게 알린다
    var onUpdate: (FeedPost) -> Void = { _ in }
    /// 신고·차단으로 숨긴 글 — 목록이 같은 글을 지우게 알린다
    var onHidden: (Int) -> Void = { _ in }

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.brandStatusInset) private var statusInset

    @State private var current: FeedPost?
    @State private var stats: FeedCategoryStats?
    @State private var votePending = false
    @State private var showAddPlan = false
    /// 탭 셸 위에 플랜 추가·수정을 연다(탭바가 남음 — Android `ADD_PLAN`). 셸 밖·다른 창 위면 예전처럼 전체 화면.
    @Environment(\.addPlanPresenter) private var addPlanPresenter

    private var item: FeedPost { current ?? post }
    private var statusBar: CGFloat { statusInset ?? wpStatusBarHeight }

    private static let muted = Color(hex: 0x9C9299)
    private static let warm = Color(hex: 0x7A6C74)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if item.hasCoordinates { mapBlock }
                    titleBlock
                    amountCard
                    reviewBlock
                    voteRow
                    if !item.hasCoordinates, let address = nonBlank(item.address) {
                        HStack(spacing: 6) {
                            WPMaterialPathIcon(paths: WPIconPaths.locationOnOutlined, size: 14, color: Color(hex: 0xB0A8AE))
                            Text(address).wpTypography(13).foregroundStyle(Self.warm)
                        }
                        .padding(.horizontal, 20).padding(.top, 24)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        // 뒤로가기 — 지도 위에 떠야 해서 면 바깥에 둔다. 숨긴 내비게이션 막대의 자리를 따라 내려가지 않게
        // 안전 영역을 무시하기 **전에** 붙인다(상태바 높이는 `statusBar` 로 직접 비운다).
        .overlay(alignment: .topLeading) { backButton }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        // Android 후기 상세(`FEED_DETAIL`)에는 하단 탭바가 없습니다
        .wpHidesTabBar()
        .task {
            // 금액이 비공개면 비교할 값이 없어 부르지도 않는다.
            guard post.amount != nil, !post.categoryName.isEmpty else { return }
            stats = try? await env.api.send(Endpoint.feedStats(categoryName: post.categoryName), decoding: FeedCategoryStats.self)
        }
        .fullScreenCover(isPresented: $showAddPlan) {
            // 리텐션 축은 코어로 되돌리는 것 — 카테고리·업체명·금액이 채워진 채로 연다.
            AddPlanView(
                prefill: AddPlanViewModel.Prefill(title: item.title, categoryName: item.categoryName,
                                                  amount: item.amount, location: item.title),
                onSaved: { showAddPlan = false }
            )
            .environmentObject(env)
        }
    }

    // MARK: - 머리

    private var backButton: some View {
        Button { dismiss() } label: {
            WPMaterialPathIcon(paths: WPIconPaths.arrowBack, size: 18, color: WPColor.textPrimary)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.9), in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("뒤로")
        .accessibilityIdentifier("feed.detail.back")
        .padding(16)
        .padding(.top, statusBar)
    }

    private var mapBlock: some View {
        let lat = item.lat ?? 0, lng = item.lng ?? 0
        return ZStack(alignment: .bottomTrailing) {
            // Android `FeedDetailScreen` — 카카오맵 줌 15
            KakaoMapView(latitude: lat, longitude: lng, zoomLevel: 15)
            Button {
                if let link = FeedRules.kakaoMapLink(item) { openURL(link) }
            } label: {
                Text("카카오맵에서 열기").wpTypography(12, .bold).foregroundStyle(WPColor.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.white, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16).padding(.bottom, 12)
        }
        .frame(height: 168)
        .background(Color(hex: 0xEAF0E6))
        .padding(.top, statusBar)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.categoryName).wpTypography(12, .bold).foregroundStyle(WPColor.primary)
            Color.clear.frame(height: 8)
            Text(item.title).wpTypography(24, .bold, lineHeight: 30).tracking(-0.72).foregroundStyle(WPColor.fgNeutral)
                .fixedSize(horizontal: false, vertical: true)
            if item.hasCoordinates, let address = nonBlank(item.address) {
                Color.clear.frame(height: 8)
                Text(address).wpTypography(13).foregroundStyle(Self.warm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, item.hasCoordinates ? 20 : 64 + statusBar)
        .padding(.bottom, 16)
    }

    // MARK: - 금액 카드

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("이 후기의 지출").wpTypography(12).foregroundStyle(Self.muted)
            Color.clear.frame(height: 6)
            if let amount = item.amount {
                WPTmoneyText(text: "\(withThousands(amount * 10_000))원", size: 34, bold: true,
                             color: UIColor(WPColor.fgNeutral), lineHeight: 34, tracking: -1.5)
            } else {
                Text("금액 비공개").wpTypography(18, .bold).foregroundStyle(Self.muted)
            }
            Color.clear.frame(height: 8)
            Text(whenLine).wpTypography(12).foregroundStyle(Self.muted)
            if let stats, let amount = item.amount {
                Color.clear.frame(height: 20)
                Hairline()
                Color.clear.frame(height: 16)
                ruler(stats, amount: amount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var whenLine: String {
        var parts: [String] = []
        let when = FeedRules.describeWhen(item.createDate)
        if !when.isEmpty { parts.append(when) }
        if let dday = item.authorDDay, dday > 0 { parts.append("결혼식 \(dday)일 전") }
        return parts.joined(separator: " · ")
    }

    /// 자를 p25~p75 로 잡지 않는다 — p25·p75 를 안쪽 눈금으로 두고 양옆에 여유를 준다.
    private func ruler(_ stats: FeedCategoryStats, amount: Double) -> some View {
        let low = FeedRules.scalePercent(stats.p25, stats: stats)
        let high = FeedRules.scalePercent(stats.p75, stats: stats)
        let mine = FeedRules.scalePercent(amount, stats: stats)
        let faint = Color(hex: 0xB0A8AE)
        return VStack(alignment: .leading, spacing: 0) {
            Text("\(item.categoryName) 후기 \(stats.sampleCount)건 안에서").wpTypography(12).foregroundStyle(Self.muted)
            Color.clear.frame(height: 8)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    Capsule().fill(Color(hex: 0xF0EEF1)).frame(width: w, height: 6).offset(y: 28)
                    Capsule().fill(Color(hex: 0xE4DFE3)).frame(width: w * (high - low) / 100, height: 6)
                        .offset(x: w * low / 100, y: 28)
                    Text("이 후기").wpTypography(10, .bold).foregroundStyle(WPColor.primary)
                        .frame(width: 48).offset(x: w * mine / 100 - 24)
                    RoundedRectangle(cornerRadius: 1).fill(WPColor.primary).frame(width: 3, height: 12)
                        .offset(x: w * mine / 100 - 1.5, y: 25)
                }
            }
            .frame(height: 34)
            Color.clear.frame(height: 16)
            HStack(spacing: 0) {
                Text("\(withThousands(stats.p25))만").wpTypography(10).foregroundStyle(faint)
                Spacer(minLength: 0)
                Text("중앙값 \(withThousands(stats.median))만").wpTypography(10).foregroundStyle(faint)
                Spacer(minLength: 0)
                Text("\(withThousands(stats.p75))만").wpTypography(10).foregroundStyle(faint)
            }
        }
    }

    // MARK: - 후기

    private var reviewBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("후기").wpTypography(15, .bold).foregroundStyle(WPColor.fgNeutral)
            Color.clear.frame(height: 12)
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { n in
                    WPMaterialPathIcon(paths: FeedIconPaths.starFilled, size: 18,
                                       color: n <= item.rating ? Color(hex: 0xF5A623) : Color(hex: 0xDCD6DA))
                }
                Color.clear.frame(width: 8)
                Text(String(format: "%.1f", Double(item.rating))).wpTypography(13).foregroundStyle(Self.muted)
            }
            .accessibilityElement(children: .ignore).accessibilityLabel("만족도 \(item.rating)점")
            if let text = nonBlank(item.body?.trimmingCharacters(in: .whitespacesAndNewlines)) {
                Color.clear.frame(height: 16)
                Text(text).wpTypography(14, lineHeight: 24.5).foregroundStyle(Color(hex: 0x3D3138))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Color.clear.frame(height: 20)
            Hairline()
            Color.clear.frame(height: 16)
            HStack(spacing: 12) {
                Text(roleBadge).wpTypography(11, .bold).foregroundStyle(WPColor.brand700)
                    .frame(width: 34, height: 34).background(WPColor.brand100, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(FeedRules.describeAuthor(item)).wpTypography(13, .bold).foregroundStyle(WPColor.fgNeutral)
                    if let region = nonBlank(item.region) {
                        Text(region).wpTypography(12).foregroundStyle(Self.muted)
                    }
                }
                Spacer(minLength: 0)
                // 신고·차단은 **작성자 줄 옆** — 누구를 신고하는지가 바로 옆에 적혀 있어야 헷갈리지 않는다.
                if !item.isMine {
                    ModerationMenu(targetType: "FEED", targetId: item.id) { onHidden(item.id); dismiss() }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 28)
    }

    private var roleBadge: String {
        switch item.authorRole {
        case "BRIDE": "신부"
        case "GROOM": "신랑"
        default: "부부"
        }
    }

    // MARK: - 투표

    private var voteRow: some View {
        HStack(spacing: 8) {
            votePill("도움이 돼요 \(item.helpfulCount)", kind: .thumbUp, vote: .helpful)
            // "안 돼요" 수는 화면에 절대 내지 않는다.
            votePill("도움이 안 돼요", kind: .thumbDown, vote: .notHelpful)
        }
        .padding(.horizontal, 20).padding(.top, 20)
    }

    private func votePill(_ label: String, kind: WPMaterialIcon.Kind, vote: FeedRules.Vote) -> some View {
        let on = item.myVote == vote.rawValue
        let tint = on ? WPColor.brand700 : Self.warm
        return Button { Task { await self.vote(vote) } } label: {
            HStack(spacing: 6) {
                WPMaterialIcon(kind: kind).fill(tint).frame(width: 14, height: 14)
                Text(label).wpTypography(13, .bold).foregroundStyle(tint)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(on ? WPColor.brand100 : WPColor.fill, in: Capsule())
            .opacity(votePending ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(votePending)
    }

    /// 목록과 같은 규칙 — 같은 값을 다시 누르면 취소, 낙관적으로 그린다.
    private func vote(_ value: FeedRules.Vote) async {
        guard !votePending else { return }
        let before = item
        let next = FeedRules.applyVote(current: before.myVote, helpfulCount: before.helpfulCount, tapped: value)
        var optimistic = before
        optimistic.myVote = next.myVote
        optimistic.helpfulCount = next.helpfulCount
        current = optimistic
        votePending = true
        defer { votePending = false }
        do {
            let result = try await env.api.send(
                next.isCancel ? Endpoint.cancelFeedVote(id: before.id) : Endpoint.voteFeedPost(id: before.id, value: value.rawValue),
                decoding: FeedVoteResult.self)
            var settled = optimistic
            settled.myVote = result.myVote
            settled.helpfulCount = result.helpfulCount
            current = settled
            onUpdate(settled)
        } catch {
            current = before
        }
    }

    // MARK: - 바닥

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Hairline()
            Button {
                let opened = addPlanPresenter?.open(AddPlanRequest(prefill: .init(title: item.title, categoryName: item.categoryName,
                                                                                  amount: item.amount, location: item.title))) ?? false
                if !opened { showAddPlan = true }
            } label: {
                HStack(spacing: 8) {
                    WPMaterialPathIcon(paths: FeedIconPaths.add, size: 18, color: .white)
                    Text("내 플랜에 담기").wpTypography(15, .bold).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("feed.detail.copy")
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
        }
        .background(Color.white)
    }

    private func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
