import SwiftUI
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 후기 상세 — 웹 `app/feed/FeedDetailView.tsx`.
///
/// 짜임은 **머리글 → 회색 금액 카드 → 시세 자 → 본문 → 바닥 담기**다.
///
/// ## 백엔드에 단건 조회가 없다
///
/// 그래서 **목록이 이미 받아 둔 항목을 그대로 넘긴다** — 카드를 누르는 흐름에서는
/// 요청이 0 개다. iOS 는 `NavigationStack` 이 값을 그대로 실어 나르므로 웹의
/// `lib/feedDetail.ts` 같은 임시 저장소가 필요 없다.
///
/// ## 지도
///
/// **좌표가 없으면 지도 블록을 통째로 내지 않는다.** 카테고리 아이콘 면으로 채워
/// 봤다가 걷어냈다 — 정보가 하나도 없는데 168pt 을 먹는다. 지도는 "이 후기가
/// 어디서 있었나" 에 답하는 자리이고, 장소가 없으면 그 질문 자체가 없다.
/// 주소 줄도 함께 사라진다 — 목록 카드와 같은 규칙이다.
///
/// iOS 는 카카오 지도 SDK 를 아직 안 붙였다. **회색 상자로 채우지 않고** 좌표가
/// 있을 때 카카오맵으로 넘어가는 줄만 낸다.
struct FeedDetailView: View {
    var post: FeedPost

    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var stats: FeedCategoryStats?
    @State private var showAddPlan = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    head
                    amountCard
                    if let stats, post.amount != nil {
                        ruler(stats)
                    }
                    bodyBlock
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task {
            // 금액이 비공개면 비교할 값이 없어 부르지도 않는다.
            guard post.amount != nil, !post.categoryName.isEmpty else { return }
            stats = try? await env.api.send(
                Endpoint.feedStats(categoryName: post.categoryName),
                decoding: FeedCategoryStats.self
            )
        }
        .fullScreenCover(isPresented: $showAddPlan) {
            // **리텐션 축은 코어로 되돌리는 것이다** — 카테고리·업체명·금액이
            // 채워진 채로 열린다. 금액이 비공개면 비워 둔다(0 을 넣으면
            // "0원짜리 일정" 이 된다).
            AddPlanView(
                prefill: AddPlanViewModel.Prefill(
                    title: post.title,
                    categoryName: post.categoryName,
                    amount: post.amount,
                    location: post.address ?? post.region
                ),
                onSaved: { showAddPlan = false }
            )
            .environmentObject(env)
        }
    }

    // MARK: - 머리글

    private var head: some View {
        BrandHead(corner: 24) {
            HStack(spacing: 0) {
                HeadIconButton(systemName: "arrow.left", label: "뒤로가기", size: 32, iconSize: 20) {
                    dismiss()
                }
                .offset(x: -8)
                Text(post.categoryName)
                    .font(WPFont.hak(15, .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
            }

            Spacer().frame(height: 12)

            Text(post.title)
                .font(WPFont.tmoney(24, .bold))
                .tracking(-0.03 * 24)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 10)

            HStack(spacing: 8) {
                Stars(rating: post.rating, size: 13)
                Text(FeedRules.describeAuthor(post))
                    .font(WPFont.hak(12.5))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer(minLength: 0)
            }

            placeLine
        }
    }

    /// 좌표가 없으면 **줄 자체를 내지 않는다.**
    @ViewBuilder
    private var placeLine: some View {
        let place = [post.address, post.region]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }

        if let place {
            Spacer().frame(height: 12)
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                Text(place)
                    .font(WPFont.hak(12.5))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                if let link = FeedRules.kakaoMapLink(post) {
                    Button { openURL(link) } label: {
                        Text("카카오맵")
                            .font(WPFont.hak(12.5, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.22), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 금액

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("실제 지출")
                .font(WPFont.hak(12.5))
                .foregroundStyle(WPColor.fgSubtle)

            if let amount = post.amount {
                Text("\(withThousands(amount))만원")
                    .font(WPFont.tmoney(30, .bold))
                    .tracking(-0.03 * 30)
                    .foregroundStyle(WPColor.textPrimary)
            } else {
                // `?? 0` 으로 채우면 "0원" 으로 그려진다.
                Text("금액 비공개")
                    .font(WPFont.tmoney(20, .bold))
                    .foregroundStyle(WPColor.gray400)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - 시세 자

    /// 같은 카테고리 안에서의 자리.
    ///
    /// **표본이 적은 카테고리는 서버가 아예 안 내려 준다**(`MIN_STATS_SAMPLE` = 5) —
    /// 화면에서 다시 세지 않고 받은 것만 그린다. 3개로 시세를 말하는 건 조작보다
    /// 큰 거짓말이다.
    private func ruler(_ stats: FeedCategoryStats) -> some View {
        let mine = FeedRules.scalePercent(post.amount ?? 0, stats: stats)
        let low = FeedRules.scalePercent(stats.p25, stats: stats)
        let high = FeedRules.scalePercent(stats.p75, stats: stats)

        return VStack(alignment: .leading, spacing: 0) {
            Text("\(post.categoryName) 후기 \(stats.sampleCount)건 안에서")
                .font(WPFont.hak(12))
                .foregroundStyle(Color(hex: 0x9C9299))

            Spacer().frame(height: 20)

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .topLeading) {
                    Capsule().fill(Color(hex: 0xF0EEF1))
                        .frame(height: 6)
                    // 가운데 절반(p25~p75). **자의 끝이 아니다.**
                    Capsule().fill(Color(hex: 0xE4DFE3))
                        .frame(width: width * (high - low) / 100, height: 6)
                        .offset(x: width * low / 100)
                    // 내 후기의 자리.
                    Circle().fill(WPColor.primary)
                        .frame(width: 12, height: 12)
                        .offset(x: width * mine / 100 - 6, y: -3)
                }
            }
            .frame(height: 12)

            Spacer().frame(height: 10)

            HStack {
                Text("중앙값 \(withThousands(stats.median))만원")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.fgSubtle)
                Spacer(minLength: 8)
                Text("\(withThousands(stats.p25)) ~ \(withThousands(stats.p75))만원")
                    .font(WPFont.hak(12))
                    .foregroundStyle(WPColor.fgSubtle)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(WPColor.strokeSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - 본문

    @ViewBuilder
    private var bodyBlock: some View {
        let text = post.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !text.isEmpty {
            Text(text)
                .font(WPFont.hak(14))
                .lineSpacing(23 - 14)
                .foregroundStyle(FeedCard.warmMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
        }
    }

    // MARK: - 바닥

    /// **리텐션 축은 코어로 되돌리는 것이다.** 등록 화면을 카테고리·업체명·금액이
    /// 채워진 채로 연다.
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Hairline()
            Button { showAddPlan = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("내 플랜에 담기")
                        .font(WPFont.hak(16, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    WPColor.primary,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.white)
    }
}
