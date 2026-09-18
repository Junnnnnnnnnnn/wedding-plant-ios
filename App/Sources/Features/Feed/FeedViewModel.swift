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
    /// 칩은 **마스터 목록**이다. 받아 온 후기에서 뽑으면 스크롤할 때마다 칩이 늘어
    /// 누르려던 칩이 옆으로 밀린다 — 무엇으로 걸러 볼 수 있는지는 지금 화면에
    /// 뭐가 실렸는지와 무관하다.
    @Published var categories: [String] = []
    @Published var myStatus: FeedMyStatus?
    /// 투표 요청이 도는 글. 연타를 막는다.
    @Published var votePendingId: Int?
    @Published var errorMessage: String?

    var hasMore: Bool { posts.count < total }

    private var loadTask: Task<Void, Never>?

    // MARK: - 목록

    func load(env: AppEnvironment, replace: Bool) async {
        if replace {
            loading = true
        } else {
            guard !loadingMore, hasMore else { return }
            loadingMore = true
        }
        errorMessage = nil
        defer {
            loading = false
            loadingMore = false
        }

        let nextPage = replace ? 1 : page + 1
        do {
            let result = try await env.api.send(
                Endpoint.feedList(
                    page: nextPage,
                    count: Self.pageCount,
                    sort: sort.rawValue,
                    categoryName: category
                ),
                decoding: FeedPage.self
            )
            posts = replace ? result.list : posts + result.list
            total = result.total
            page = nextPage
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }

        if replace { await loadMyStatus(env: env) }
    }

    /// 사이드는 부가 정보다. 실패해도 목록은 그대로 본다.
    private func loadMyStatus(env: AppEnvironment) async {
        myStatus = try? await env.api.send(Endpoint.feedMyStatus(), decoding: FeedMyStatus.self)
    }

    /// 칩은 **공용** 카테고리 목록을 쓴다 — 후기는 방이 아니라 개인 자격으로 올리고,
    /// 내가 안 쓰는 카테고리도 남의 후기에는 있다.
    func loadCategories(env: AppEnvironment) async {
        guard categories.isEmpty else { return }
        // 칩이 없어도 목록은 보인다. 실패는 조용히 넘어간다.
        guard let page = try? await env.api.send(
            Endpoint.categoryList(), decoding: PlanCategoryPage.self
        ) else { return }
        categories = page.list.map(\.name).filter { !$0.isEmpty }
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
        guard votePendingId == nil else { return }
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
            guard let now = posts.firstIndex(where: { $0.id == post.id }) else { return }
            posts[now] = before
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
