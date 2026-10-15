import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking

/// 웹 `app/brag/page.tsx` 이식.
///
/// **피드와 규칙이 정반대다** — 여기는 닉네임을 내는 것이 목적이다.
/// 피드 코드를 베껴 올 때 익명 처리를 함께 가져오지 말 것.
@MainActor
final class BragViewModel: ObservableObject {

    private static let pageCount = 20

    /// 안드로이드 `BragViewModel.Sort` — 서버 `sort` 값과 칩 글자
    enum Sort: String, CaseIterable, Identifiable {
        case recent = "RECENT", liked = "LIKED"
        var id: String { rawValue }
        var label: String { self == .recent ? "최신순" : "좋아요순" }
    }

    @Published var sort: Sort = .recent
    @Published var loading = true
    @Published var loadingMore = false
    @Published var posts: [BragPost] = []
    @Published var total = 0
    @Published var myStatus: BragMyStatus?
    @Published var page = 1
    @Published var likePendingId: Int?
    @Published var errorMessage: String?

    var hasMore: Bool { posts.count < total }

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

        if replace { myStatus = try? await env.api.send(Endpoint.bragMy(), decoding: BragMyStatus.self) }
        let nextPage = replace ? 1 : page + 1
        do {
            var request = Endpoint.bragList(page: nextPage, count: Self.pageCount)
            request.query["sort"] = sort.rawValue
            let result = try await env.api.send(request, decoding: BragPage.self)
            posts = replace ? result.list : posts + result.list
            total = result.total
            page = nextPage
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setSort(_ next: Sort, env: AppEnvironment) async {
        guard next != sort else { return }
        sort = next
        await load(env: env, replace: true)
    }

    /// 내 카드의 `내려두기` — 성공하면 목록에서 뺀다. 실패하면 카드가 그대로 남는다(잘못 사라지는 것보다 낫다).
    func unpublish(_ bragId: Int, env: AppEnvironment) async {
        do {
            try await env.api.sendIgnoringData(Endpoint.unpublishBrag())
            hide(bragId)
            if myStatus != nil { myStatus?.published = false }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 신고·차단한 글을 그 자리에서 치운다. 두 번 불려도 총 개수가 두 번 줄지 않게.
    func hide(_ bragId: Int) {
        guard let index = posts.firstIndex(where: { $0.bragId == bragId }) else { return }
        posts.remove(at: index)
        total = max(0, total - 1)
    }

    /// 상세에서 누른 좋아요를 목록 카드에도 맞춘다.
    func applyLike(bragId: Int, liked: Bool, count: Int) {
        guard let index = posts.firstIndex(where: { $0.bragId == bragId }) else { return }
        posts[index].liked = liked
        posts[index].likeCount = count
    }

    /// 좋아요는 **낙관적으로** 그린다(피드의 투표와 같은 규칙). 실패하면 되돌린다.
    func toggleLike(_ post: BragPost, env: AppEnvironment) async {
        guard likePendingId == nil else { return }
        guard let index = posts.firstIndex(where: { $0.bragId == post.bragId }) else { return }

        let before = posts[index]
        let next = BragRules.applyLike(liked: before.liked, likeCount: before.likeCount)
        posts[index].liked = next.liked
        posts[index].likeCount = next.likeCount

        likePendingId = post.bragId
        defer { likePendingId = nil }

        do {
            let result = try await env.api.send(
                next.liked
                    ? Endpoint.likeBrag(id: post.bragId)
                    : Endpoint.unlikeBrag(id: post.bragId),
                decoding: BragLikeResult.self
            )
            guard let now = posts.firstIndex(where: { $0.bragId == post.bragId }) else { return }
            if let liked = result.liked { posts[now].liked = liked }
            if let count = result.likeCount { posts[now].likeCount = count }
        } catch {
            guard let now = posts.firstIndex(where: { $0.bragId == post.bragId }) else { return }
            posts[now] = before
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// 상세 모달. `GET /plan/brag/{id}`
@MainActor
final class BragDetailViewModel: ObservableObject {
    @Published var loading = true
    @Published var detail: BragDetail?
    @Published var errorMessage: String?

    /// 카테고리로 묶고 소계를 내는 것은 **프론트가 한다** —
    /// 서버에 두면 문구 하나 고치는 데 백엔드 배포가 묶인다.
    var groups: [BragRules.Group] {
        guard let detail else { return [] }
        return BragRules.groups(items: detail.items, chart: detail.categoryChart)
    }

    func load(id: Int, env: AppEnvironment) async {
        loading = true
        defer { loading = false }
        do {
            detail = try await env.api.send(Endpoint.brag(id: id), decoding: BragDetail.self)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// 홈 예산 패널의 토글. `GET /plan/brag/my` · `PUT`/`DELETE /plan/brag`
///
/// **상태를 모듈 한 곳에 모아 둔다.** 웹은 `/main` 이 폰 트리와 대시보드를 둘 다
/// 렌더해 같은 DOM 을 쓸 수 없어서 그렇게 했는데, iOS 는 화면이 하나라 그 이유는
/// 없다 — 다만 홈이 다시 그려질 때마다 `/plan/brag/my` 를 또 부르지 않도록
/// `@StateObject` 하나로 들고 있는다.
@MainActor
final class BragToggleViewModel: ObservableObject {
    @Published var status: BragMyStatus?
    @Published var pending = false
    @Published var errorMessage: String?

    var published: Bool { status?.published ?? false }

    func load(env: AppEnvironment) async {
        status = try? await env.api.send(Endpoint.bragMy(), decoding: BragMyStatus.self)
    }

    /// 올린다. **켜기 전에는 반드시 안내 시트를 거친다** — 호출부가 책임진다.
    /// `title` 은 자랑하기에 보일 이름 — 비우면 서버가 두 사람 이름(`defaultNickname`)으로 만든다.
    func publish(title: String = "", env: AppEnvironment) async {
        guard !pending else { return }
        pending = true
        defer { pending = false }
        struct Body: Encodable { let title: String }
        do {
            try await env.api.sendIgnoringData(HTTPRequest.json(.put, "/plan/brag",
                body: Body(title: title.trimmingCharacters(in: .whitespacesAndNewlines))))
            await load(env: env)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 내린다. **되돌릴 수 있으므로 확인을 받지 않는다.**
    /// 행은 지워지지 않아 다시 올리면 좋아요가 이어진다.
    func unpublish(env: AppEnvironment) async {
        guard !pending else { return }
        pending = true
        defer { pending = false }
        do {
            try await env.api.sendIgnoringData(Endpoint.unpublishBrag())
            await load(env: env)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
