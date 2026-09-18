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

    @Published var loading = true
    @Published var loadingMore = false
    @Published var posts: [BragPost] = []
    @Published var total = 0
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

        let nextPage = replace ? 1 : page + 1
        do {
            let result = try await env.api.send(
                Endpoint.bragList(page: nextPage, count: Self.pageCount),
                decoding: BragPage.self
            )
            posts = replace ? result.list : posts + result.list
            total = result.total
            page = nextPage
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
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

    /// 올린다. **켜기 전에는 반드시 안내 모달을 거친다** — 호출부가 책임진다.
    func publish(env: AppEnvironment) async {
        guard !pending else { return }
        pending = true
        defer { pending = false }
        do {
            try await env.api.sendIgnoringData(Endpoint.publishBrag())
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
