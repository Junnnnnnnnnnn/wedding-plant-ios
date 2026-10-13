import SwiftUI
import WPDomain
import WPModels
import WPUtils

/// 웹 `app/feed/page.tsx` 의 폰 트리 — **시안 D, 한 줄 카드**.
///
/// **왼쪽에 금액 하나만 크게 둔다.** 이 화면에서 사람이 실제로 하는 일이 "금액을
/// 위아래로 훑는 것" 이라, 금액이 같은 x 좌표에 세로로 줄서야 비교가 된다 —
/// **금액을 카드 안쪽으로 넣지 말 것.**
///
/// **목록에 지도를 깔지 않는다.** 카드의 장소 줄은 도로명 주소 한 줄 + `카카오맵`
/// 링크다. 작은 지도를 카드마다 붙이면 금액을 세로로 훑는 설계가 깨지고
/// staticmap 쿼터·로딩이 붙는다.
///
/// 리텐션 축은 **코어로 되돌리는 것**이다. `내 플랜에 담기` 가 등록 화면을 값이
/// 채워진 채로 연다. 무한 스크롤로 시간을 뺏는 화면이 아니다.
struct FeedView: View {
    var titleSlot: AnyView? = nil
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var model = FeedViewModel()
    @State private var path = NavigationPath()
    @State private var showPostSheet = false
    @State private var copyPost: FeedPost?

    var body: some View {
        NavigationStack(path: $path) {
            content
        }.onChange(of: env.moderationRevision) { _, _ in Task { await model.load(env: env, replace: true) } }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    head
                    chips
                    sortRow

                    if model.loading {
                        ForEach(0..<4, id: \.self) { _ in SkeletonRow() }
                    } else if model.posts.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.posts) { post in
                            FeedCard(
                                post: post,
                                votePending: model.votePendingId == post.id,
                                onVote: { vote in
                                    Task { await model.vote(post, vote, env: env) }
                                },
                                onOpen: { path.append(post) },
                                onCopy: { copyPost = post }
                            )
                        }

                        if model.hasMore {
                            moreButton
                        }
                    }
                }
                .id(model.loading)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            if let message = model.errorMessage {
                InfoBanner(message: message, actionLabel: "닫기") {
                    model.errorMessage = nil
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await model.loadCategories(env: env)
            await model.load(env: env, replace: true)
        }
        .navigationDestination(for: FeedPost.self) { post in
            FeedDetailView(post: post)
        }
        .fullScreenCover(item: $copyPost) { post in
            AddPlanView(prefill: .init(title: post.title, categoryName: post.categoryName,
                                      amount: post.amount, location: post.address ?? post.region),
                        onSaved: { copyPost = nil })
                .environmentObject(env)
        }
        // 후기 작성은 별도 라우트가 아니라 **완료한 일정에서 여는 모달**이다.
        .sheet(isPresented: $showPostSheet) {
            FeedPostSheet {
                Task { await model.load(env: env, replace: true) }
            }
            .environmentObject(env)
        }
    }

    // MARK: - 머리 면

    private var head: some View {
        ExploreHead(switcher: titleSlot ?? AnyView(Text("견적 후기").wpTypography(18, .bold).foregroundStyle(.white)),
                    headline: "다른 커플은 얼마 썼을까",
                    stats: [("후기", "\(model.total)개")] + (env.isAuthenticated ? [("내 후기", "\(model.myStatus?.postCount ?? 0)개"), ("받은 도움", "\(model.myStatus?.receivedHelpfulCount ?? 0)")] : []),
                    loading: model.loading && model.posts.isEmpty, action: { showPostSheet = true }) {
            if let status = model.myStatus, status.postableScheduleCount > 0 {
                Button { showPostSheet = true } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("완료한 일정 \(status.postableScheduleCount)개를 아직 안 올렸어요").wpTypography(14, .bold)
                            Text("올리면 다른 커플의 후기도 더 잘 보입니다").wpTypography(12).opacity(0.75)
                        }
                        Spacer(minLength: 0); WPMaterialIcon(kind: .right).frame(width: 18, height: 18)
                    }.foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 12).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).padding(.top, 12).accessibilityIdentifier("feed.write")
            }
        }
    }
    private var sortRow: some View {
        HStack(spacing: 12) {
            ForEach(FeedViewModel.Sort.allCases) { option in
                Button { Task { await model.setSort(option, env: env) } } label: {
                    Text(option.label).wpTypography(13, model.sort == option ? .bold : .regular).foregroundStyle(model.sort == option ? WPColor.fgNeutral : WPColor.fgSubtle)
                }.buttonStyle(.plain)
            }
            Spacer()
        }.padding(.horizontal, 20).padding(.bottom, 4)
    }

    // MARK: - 카테고리 칩

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                chip(label: "전체", selected: model.category == nil) {
                    Task { await model.setCategory(nil, env: env) }
                }
                ForEach(model.categories, id: \.self) { name in
                    chip(label: name, selected: model.category == name) {
                        Task { await model.setCategory(name, env: env) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16).padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    /// 시안(C안 04)의 채움 칩. **활성은 검정 solid** — 분홍은 "누를 것" 에만 쓴다.
    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .wpTypography(13, selected ? .bold : .regular)
                .foregroundStyle(selected ? .white : WPColor.fgMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color(hex: 0x1A1C20) : WPColor.fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 빈 상태 · 더 보기

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("아직 후기가 없어요")
                .wpTypography(16, .bold)
                .foregroundStyle(WPColor.fgNeutral)
            Text("완료한 일정에 별점과 한 줄만 얹으면 후기가 됩니다")
                .wpTypography(13)
                .foregroundStyle(WPColor.fgSubtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, 24)
    }

    private var moreButton: some View {
        Button {
            Task { await model.load(env: env, replace: false) }
        } label: {
            Text(model.loadingMore ? "불러오는 중..." : "더 보기")
                .wpTypography(14, .bold)
                .foregroundStyle(WPColor.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(WPColor.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(model.loadingMore)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - 한 줄 카드

/// 시안 D. **금액이 맨 왼쪽 위에 혼자 크게** 오고, 나머지가 그 아래로 붙는다.
struct FeedCard: View {
    var post: FeedPost
    var votePending: Bool
    var onVote: (FeedRules.Vote) -> Void
    var onOpen: () -> Void
    var onCopy: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                amountLine
                Spacer().frame(height: 6)
                Text(post.categoryName)
                    .wpTypography(12)
                    .foregroundStyle(WPColor.gray400)

                Spacer().frame(height: 12)
                HStack(alignment: .top, spacing: 8) {
                    FlowRow(spacing: 8, lineSpacing: 4, verticalAlignment: .center, wrapLongItems: true) {
                    Text(post.title)
                        .wpTypography(14.5, .bold)
                        .foregroundStyle(WPColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Stars(rating: post.rating)
                    }
                    Spacer(minLength: 0)
                    if !post.isMine { ModerationMenu(targetType: "FEED", targetId: post.id, compact: true).offset(x: 6, y: -4).foregroundStyle(WPColor.fgMuted) }
                }

                placeLine

                if let body = post.body?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !body.isEmpty {
                    Spacer().frame(height: 8)
                    Text(body)
                        .wpTypography(12.5, lineHeight: 20)
                        .foregroundStyle(Self.warmMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer().frame(height: 12)
                authorLine

                Spacer().frame(height: 8)
                actionRow
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Hairline()
        }
        .padding(.horizontal, 16)
        // 하네스가 이 식별자로 카드를 센다(웹은 `article`).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed.card")
    }

    /// **비공개면 필드 자체가 없다.** `?? 0` 으로 채우면 "0원" 으로 그려진다.
    @ViewBuilder
    private var amountLine: some View {
        if let amount = post.amount {
            WPTmoneyText(text: "\(withThousands(amount))만원", size: 23, bold: true, color: UIColor(WPColor.textPrimary), lineHeight: 23, tracking: -0.69)
                .foregroundStyle(WPColor.textPrimary)
        } else {
            Text("금액 비공개")
                .font(WPFont.tmoney(17, .bold))
                .tracking(-0.02 * 17)
                .foregroundStyle(WPColor.gray400)
        }
    }

    /// 주소가 없으면 지역, **둘 다 없으면 줄 자체를 내지 않는다.**
    /// 장소는 필수가 아니다 — "미확인" 이라고 크게 적지 않는다.
    @ViewBuilder
    private var placeLine: some View {
        let place = [post.address, post.region]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }

        if let place {
            Spacer().frame(height: 6)
            HStack(spacing: 4) {
                WPMaterialIcon(kind: .pin).frame(width: 12, height: 12)
                    .foregroundStyle(WPColor.primary)
                Text(place)
                    .wpTypography(12)
                    .foregroundStyle(Self.warmMuted)
                    .lineLimit(1)

                if let link = FeedRules.kakaoMapLink(post) {
                    Button {
                        openURL(link)
                    } label: {
                        Text("카카오맵")
                            .wpTypography(12, .bold)
                            .foregroundStyle(WPColor.primary)
                            .padding(.leading, 4)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var authorLine: some View {
        HStack(spacing: 6) {
            Text(authorText)
                .wpTypography(12)
                .foregroundStyle(WPColor.gray400)
            if post.isMine {
                Text("내 후기")
                    .wpTypography(11, .bold)
                    .foregroundStyle(WPColor.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(hex: 0xFFF2F6), in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private var authorText: String {
        let who = FeedRules.describeAuthor(post)
        let when = FeedRules.describeWhen(post.createDate)
        return when.isEmpty ? who : "\(who) · \(when)"
    }

    /// **"도움이 안 돼요" 수는 절대 공개하지 않는다.** 정직하게 올린 후기에
    /// "안 돼요 12" 가 박히면 다음 사람이 안 올린다 — 아이콘만 둔다.
    private var actionRow: some View {
        FlowRow(spacing: 8, lineSpacing: 8, verticalAlignment: .center) {
            helpfulButton
            notHelpfulButton
            Button(action: onCopy) {
                HStack(spacing: 4) {
                    WPMaterialIcon(kind: .plus).frame(width: 14, height: 14)
                    Text("내 플랜에 담기").wpTypography(12.5, .bold)
                }.foregroundStyle(WPColor.primary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().strokeBorder(WPColor.primary.opacity(0.2), lineWidth: 1))
            }.buttonStyle(.plain).accessibilityIdentifier("feed.copy.\(post.id)")
        }
    }

    private var helpfulButton: some View {
        let on = post.myVote == FeedRules.Vote.helpful.rawValue
        let tint = on ? WPColor.primary : Self.warmMuted
        return Button { onVote(.helpful) } label: {
            HStack(spacing: 6) {
                WPMaterialIcon(kind: on ? .thumbUpFill : .thumbUp).frame(width: 14, height: 14)
                Text("도움이 돼요")
                    .wpTypography(12.5, .bold)
                if post.helpfulCount > 0 {
                    Text("\(post.helpfulCount)")
                        .font(WPFont.tmoney(12.5, .bold))
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(on ? Color(hex: 0xFFF2F6) : Color.white, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    on ? WPColor.primary.opacity(0.2) : Self.warmStroke,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(votePending)
        .opacity(votePending ? 0.6 : 1)
    }

    private var notHelpfulButton: some View {
        let on = post.myVote == FeedRules.Vote.notHelpful.rawValue
        return Button { onVote(.notHelpful) } label: {
            WPMaterialIcon(kind: on ? .thumbDownFill : .thumbDown).frame(width: 14, height: 14)
                .foregroundStyle(on ? Color(hex: 0x4A3F45) : Color(hex: 0xC8BFC4))
                .frame(width: 30, height: 30)
                .background(on ? Color(hex: 0xF4EFF2) : Color.white, in: Circle())
                .overlay(
                    Circle().strokeBorder(
                        on ? Color(hex: 0xD6CCD2) : Self.warmStroke,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(votePending)
        .opacity(votePending ? 0.6 : 1)
        .accessibilityLabel("도움이 안 돼요")
    }

    /// 웹 `#7a6c74` — 따뜻한 회색. 피드 본문·장소 줄이 쓴다.
    static let warmMuted = Color(hex: 0x7A6C74)
    static let warmStroke = Color(hex: 0xEDE7EA)
}

/// 만족도 1~5.
struct Stars: View {
    var rating: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { n in
                WPMaterialIcon(kind: .star).frame(width: size, height: size)
                    .foregroundStyle(n <= rating ? Color(hex: 0xFFB020) : Color(hex: 0xE9E1E5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("만족도 \(rating)점")
    }
}

/// 실제 카드와 같은 짜임의 뼈대.
private struct SkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBox(width: 120, height: 24)
                SkeletonBox(width: 60, height: 14)
                SkeletonBox(width: 200, height: 16)
                SkeletonBox(height: 14)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 20)
            Hairline()
        }
        .padding(.horizontal, 16)
    }
}
