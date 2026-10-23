import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking

/// 웹 `app/feed/page.tsx` 이식.
///
/// 후기는 **방 권한과 무관**하다. 개인 자격으로 올리므로 `READ`/`SPOUSE` 게이트를
/// 넣지 말 것.
@MainActor
final class FeedViewModel: ObservableObject {

    /// 웹 `SORTS` 와 같은 순서·라벨.
    enum Sort: String, CaseIterable, Identifiable {
        case recent = "RECENT"
        case helpful = "HELPFUL"
        case amountAsc = "AMOUNT_ASC"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .recent: return "최신순"
            case .helpful: return "도움순"
            case .amountAsc: return "낮은 금액순"
            }
        }
    }

    private static let pageCount = 20

    @Published var loading = true
    @Published var loadingMore = false
    @Published var posts: [FeedPost] = []
    @Published var total = 0
    @Published var page = 1
    @Published var sort: Sort = .recent
    /// `nil` 이면 "전체".
    @Published var category: String?
    /// 칩은 **올라온 후기에 있는 카테고리만**, 서버가 센 순서 그대로다(`GET /plan/feed/categories`, 2026-10-22).
    /// 받아 둔 후기(20개씩)로 세면 빠지는 카테고리가 생기고 스크롤할 때마다 칩이 늘어 **화면이 세지 않는다.**
    @Published var categories: [String] = []
    @Published var myStatus: FeedMyStatus?
    /// 투표 요청이 도는 글. 연타를 막는다.
    @Published var votePendingId: Int?
    @Published var errorMessage: String?

    var hasMore: Bool { posts.count < total }

    /// 서버 `FEED_LIST_MAX_COUNT` — 내린 뒤 "받아 둔 만큼" 다시 받을 때의 상한(넘기면 400)
    private static let maxCount = 1000
    /// replace 로드마다 1씩 — 늦게 온 지난 응답(고치기 전에 시작한 GET 등)이 지금 목록을 덮지 않게 버린다
    private var loadGeneration = 0
    /// 겹친 칩 요청에서 늦게 온 옛 응답이 새 칩을 덮지 않게
    private var categoryGeneration = 0
    /// 보이지 않게 다시 받는 중 — 그 사이에 다음 장을 이어 붙이면 응답 순서에 따라 한 장이 붙었다 사라진다
    private var reloading = false

    // MARK: - 목록

    /// - Parameters:
    ///   - silent: 받아 둔 목록을 뼈대로 바꾸지 않고 뒤에서 다시 받는다
    ///   - pages: 처음부터 몇 장만큼 한 번에 받을지(보던 자리를 지키려고)
    func load(env: AppEnvironment, replace: Bool, silent: Bool = false, pages: Int = 1) async {
        if replace {
            if !silent { loading = true }
        } else {
            guard !loading, !loadingMore, !reloading, hasMore else { return }
            loadingMore = true
        }
        errorMessage = nil
        if replace { loadGeneration += 1 }
        let generation = loadGeneration
        if replace && silent { reloading = true }
        defer {
            if generation == loadGeneration {
                loading = false
                loadingMore = false
                if replace && silent { reloading = false }
            }
        }

        let nextPage = replace ? 1 : page + 1
        // 쪽 수부터 상한 안으로 줄인다 — 쪽 수를 두고 count 만 자르면 다음 '더 보기' 가 그만큼 건너뛴다
        let span = replace ? min(max(1, pages), Self.maxCount / Self.pageCount) : 1
        do {
            let result = try await env.api.send(
                Endpoint.feedList(
                    page: nextPage,
                    count: Self.pageCount * span,
                    sort: sort.rawValue,
                    categoryName: category
                ),
                decoding: FeedPage.self
            )
            guard generation == loadGeneration else { return }
            // 장 사이에 새 후기가 올라오면 앞 장의 끝이 다시 온다 — 같은 id 는 한 번만
            var seen = Set<Int>()
            posts = (replace ? result.list : posts + result.list).filter { seen.insert($0.id).inserted }
            total = result.total
            page = replace ? span : nextPage
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }

        if replace { await loadMyStatus(env: env) }
    }

    /// 사이드는 부가 정보다. 실패해도 목록은 그대로 본다.
    private func loadMyStatus(env: AppEnvironment) async {
        myStatus = try? await env.api.send(Endpoint.feedMyStatus(), decoding: FeedMyStatus.self)
    }

    /// 칩을 서버에서 다시 센다. **실패하면 받아 둔 칩을 그대로 둔다**(처음이면 `전체` 하나) — 실패 문구는 내지 않는다.
    /// 칩이 바뀌는 순간(첫 후기가 새 칩을, 마지막 후기가 칩을 없앤다)마다 부른다: 올림 · 내림 · 목록 신고 · 상세 신고.
    func loadCategories(env: AppEnvironment) async {
        categoryGeneration += 1
        let generation = categoryGeneration
        guard let page = try? await env.api.send(Endpoint.feedCategories(), decoding: FeedCategoryCountPage.self),
              generation == categoryGeneration else { return }
        categories = page.list.map(\.categoryName).filter { !$0.isEmpty }
    }

    func setSort(_ next: Sort, env: AppEnvironment) async {
        guard next != sort else { return }
        sort = next
        posts = []
        page = 1
        await load(env: env, replace: true)
    }

    func setCategory(_ next: String?, env: AppEnvironment) async {
        guard next != category else { return }
        category = next
        posts = []
        page = 1
        await load(env: env, replace: true)
    }

    // MARK: - 투표

    /// **낙관적으로 그린다.** 요청 전에 숫자를 먼저 바꾸고 응답이 오면 서버 값으로
    /// 맞춘다(동시에 누른 사람이 있으면 다를 수 있다). 실패하면 되돌린다 —
    /// 즉시 반응하지 않으면 사람들이 두 번 누른다.
    func vote(_ post: FeedPost, _ tapped: FeedRules.Vote, env: AppEnvironment) async {
        // 내 글에는 투표 단추가 없다 — 서버가 아직 자기 글 투표를 막지 않아 도움순이 부풀려진다
        guard !post.isMine, votePendingId == nil else { return }
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }

        let before = posts[index]
        let next = FeedRules.applyVote(
            current: before.myVote,
            helpfulCount: before.helpfulCount,
            tapped: tapped
        )

        posts[index].myVote = next.myVote
        posts[index].helpfulCount = next.helpfulCount
        votePendingId = post.id
        defer { votePendingId = nil }

        do {
            let result: FeedVoteResult
            if next.isCancel {
                result = try await env.api.send(
                    Endpoint.cancelFeedVote(id: post.id), decoding: FeedVoteResult.self
                )
            } else {
                result = try await env.api.send(
                    Endpoint.voteFeedPost(id: post.id, value: tapped.rawValue),
                    decoding: FeedVoteResult.self
                )
            }
            guard let now = posts.firstIndex(where: { $0.id == post.id }) else { return }
            posts[now].myVote = result.myVote
            posts[now].helpfulCount = result.helpfulCount
        } catch {
            // 투표 값만 되돌린다 — 그사이 고친 내용(사진 · 한 줄)까지 옛 값으로 돌리면 안 된다
            guard let now = posts.firstIndex(where: { $0.id == post.id }) else { return }
            posts[now].myVote = before.myVote
            posts[now].helpfulCount = before.helpfulCount
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 신고·차단한 글을 **그 자리에서** 치운다 — 서버도 빼 주지만 그건 다음에 받을 때다.
    /// 목록에 있을 때만 줄인다 — 신고 완료와 시트 닫힘이 겹쳐 두 번 불려도 총 개수가 두 번 줄지 않게.
    func hide(_ id: Int) {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
        posts.remove(at: index)
        total = max(0, total - 1)
    }

    /// 신고 · 차단 뒤 — 글을 치우고 **칩도 다시 센다.** 목록에 없는 글이어도 부른다: 차단은 그 작성자의 **다른
    /// 카테고리 글**까지 빼서, 그 사람 글만 있던 칩이 사라진다.
    func hideAndRecount(_ id: Int, env: AppEnvironment) async {
        hide(id)
        await loadCategories(env: env)
    }

    /// 고친 후기를 서버 응답 그대로 끼운다(다시 받지 않음). 고치기 전에 시작한 GET 이 뒤늦게 옛 값으로 돌리지 않게
    /// 세대를 올린다. 고치기로는 카테고리를 바꿀 수 없어 칩은 다시 세지 않는다.
    func applyEdited(_ post: FeedPost, env: AppEnvironment) async {
        loadGeneration += 1
        reloading = false
        loading = false
        loadingMore = false
        replace(post)
        await loadMyStatus(env: env)
    }

    /// 내린 후기 — 목록에서 빼고(총 개수도), 다음 장의 시작점이 당겨지므로 이미 본 쪽을 조용히 다시 맞추고, 칩도 다시 센다
    /// (그 카테고리의 마지막 후기였으면 칩이 빠진다 — 고른 채였으면 끝에 남는다, `FeedRules.chips`).
    func applyDeleted(_ id: Int, env: AppEnvironment) async {
        let pages = (posts.count + Self.pageCount - 1) / Self.pageCount
        loadGeneration += 1
        reloading = false
        hide(id)
        loading = false
        loadingMore = false
        async let list: Void = load(env: env, replace: true, silent: true, pages: pages)
        async let chips: Void = loadCategories(env: env)
        _ = await (list, chips)
    }

    /// 후기를 올린 뒤 — 목록 · 요약 · 칩(새 카테고리의 첫 후기면 칩이 생긴다)
    func refreshAfterPost(env: AppEnvironment) async {
        posts = []
        page = 1
        async let list: Void = load(env: env, replace: true)
        async let chips: Void = loadCategories(env: env)
        _ = await (list, chips)
    }

    /// 상세에서 바꾼 투표를 목록에도 맞춘다(안드로이드 `FeedDetailHandoff.put`).
    func replace(_ post: FeedPost) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index] = post
    }
}
