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
    /// 탭 셸 위에 플랜 추가·수정을 연다(탭바가 남음 — Android `ADD_PLAN`). 셸 밖·다른 창 위면 예전처럼 전체 화면.
    @Environment(\.addPlanPresenter) private var addPlanPresenter

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
                    if !env.isAuthenticated {
                        loginPrompt
                    } else {
                    chips
                    sortRow

                    if model.loading {
                        ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
                    } else if model.posts.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(model.posts.enumerated()), id: \.element.id) { index, post in
                            FeedCard(
                                post: post,
                                votePending: model.votePendingId == post.id,
                                onVote: { vote in
                                    Task { await model.vote(post, vote, env: env) }
                                },
                                onOpen: { path.append(post) },
                                onCopy: {
                                    let opened = addPlanPresenter?.open(AddPlanRequest(prefill: .init(title: post.title, categoryName: post.categoryName,
                                                                                                     amount: post.amount, location: post.title))) ?? false
                                    if !opened { copyPost = post }
                                },
                                onHidden: { model.hide(post.id) }
                            )
                            if AdRules.adAfter(index: index, count: model.posts.count, first: 3, every: 8) {
                                NativeAdSlot(placement: "feed.\(index)", style: .feed, horizontal: 16, top: 8, bottom: 8)
                            }
                        }

                        // 안드로이드처럼 끝에 닿으면 다음 장을 받는다(`더 보기` 단추 없음).
                        if model.hasMore {
                            loadMoreRow
                        }
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
            FeedDetailView(post: post, onUpdate: { model.replace($0) }, onHidden: { model.hide($0) })
        }
        .fullScreenCover(item: $copyPost) { post in
            AddPlanView(prefill: .init(title: post.title, categoryName: post.categoryName,
                                      amount: post.amount, location: post.title),
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

    /// 안드로이드 `FeedEmpty` — 테두리 카드 + 올릴 수 있는 일정 보기
    private var emptyState: some View {
        VStack(spacing: 0) {
            Text("아직 후기가 없어요").wpTypography(14, .bold).foregroundStyle(WPColor.textPrimary)
            Color.clear.frame(height: 8)
            Text("완료한 일정을 올리면 다른 커플이 견적을 가늠할 수 있어요.".wpKeepAll)
                .wpTypography(12.5, lineHeight: 19).foregroundStyle(FeedCard.warmMuted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Color.clear.frame(height: 16)
            Button { showPostSheet = true } label: {
                Text("올릴 수 있는 일정 보기").wpTypography(13, .bold).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(WPColor.cardBorder, lineWidth: 1))
        .padding(16)
    }

    /// 안드로이드 `FeedLoginPrompt`
    private var loginPrompt: some View {
        VStack(spacing: 16) {
            Text("로그인하면 견적 후기를 볼 수 있어요").wpTypography(15, .bold).foregroundStyle(WPColor.textPrimary)
            Button { env.isAuthenticated = false } label: {
                Text("로그인하기").wpTypography(14, .bold).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(WPColor.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32).padding(.vertical, 80)
    }

    /// 끝에 닿으면 다음 장 — 안드로이드는 끝에서 3개 남으면 받고 받는 동안 20pt 스피너를 둔다.
    private var loadMoreRow: some View {
        ZStack {
            if model.loadingMore {
                ProgressView().tint(WPColor.primary).controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: model.loadingMore ? 52 : 1)
        .onAppear { Task { await model.load(env: env, replace: false) } }
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
    /// 신고·차단이 끝나 이 글을 목록에서 치울 때
    var onHidden: () -> Void = {}

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
                    // **내 글에는 안 낸다** — 자기 글 신고는 서버가 거절한다. 웹 `-mr-1 -mt-0.5`
                    if !post.isMine { ModerationMenu(targetType: "FEED", targetId: post.id, onHidden: onHidden).offset(x: 6, y: -4) }
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
            WPTmoneyText(text: "금액 비공개", size: 17, bold: true, color: UIColor(WPColor.gray400), tracking: -0.34)
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
    static let warmStroke = Color(hex: 0xEFE7EB)
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

/// 실제 카드와 같은 짜임의 뼈대 — 안드로이드 `SkeletonRow`.
private struct SkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SkeletonBox(width: 96, height: 23)
                Color.clear.frame(height: 6)
                SkeletonBox(width: 48, height: 12)
                Color.clear.frame(height: 12)
                SkeletonBox(width: 128, height: 16)
                Color.clear.frame(height: 10)
                GeometryReader { g in SkeletonBox(width: g.size.width * 0.8, height: 14) }.frame(height: 14)
                Color.clear.frame(height: 16)
                HStack(spacing: 8) {
                    SkeletonBox(width: 112, height: 32, corner: 16)
                    SkeletonBox(width: 32, height: 32, corner: 16)
                    SkeletonBox(width: 128, height: 32, corner: 16)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 20)
            Hairline()
        }
        .padding(.horizontal, 16)
    }
}
