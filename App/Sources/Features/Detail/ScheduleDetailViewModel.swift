import Combine
import Foundation
import WPModels
import WPNetworking
import WPDomain
import WPUtils

/// 웹 `app/schedule-detail/page.tsx` 의 상태 관리.
@MainActor
final class ScheduleDetailViewModel: ObservableObject {
    @Published var loading = true
    @Published var detail: ScheduleDetail?
    @Published var errorMessage: String?
    @Published var deleting = false
    /// 삭제 완료 — 화면에서 뒤로 가야 함
    @Published var deleted = false
    @Published var sessionExpired = false
    @Published var isGuest = false
    /// 완료 토글을 보내는 중 — 안드로이드 `statusPending`
    @Published var statusPending = false
    /// 채팅으로 보내기 줄의 부제(`현우에게 이 플랜을 보내요`)를 고르는 신랑·신부 대화 판정.
    /// 안드로이드 `CoupleChatStore` 와 같은 `/plan/room/list` 를 같은 규칙(`CoupleChatRules.pick`)으로 읽는다.
    @Published var couple: CoupleChatState = .loading
    /// `/plan/feed/postable` 의 일정 id. `nil` = 아직 못 받음(받는 중) — 안드로이드 `postablesLoaded`
    @Published var postableIds: Set<Int>?

    @Published var permission: PlanPermission?
    @Published var roomId: Int?
    var canWrite: Bool { isGuest || permission.map { $0.canEdit } == true }
    var canSeeDocuments: Bool { !isGuest && (permission == .owner || permission == .spouse) }
    let scheduleId: Int

    /// 피드 줄의 네 모습 — 안드로이드 `FeedShare`(올릴 수 있음 · 받는 중(흐리게) · 예정이라 잠김 · 뺌)
    enum FeedShare { case ready, checking, locked, hidden }

    /// 피드는 **내가 만든 완료 일정**만 받는다(서버 `/plan/feed/postable`). 판정은 안드로이드
    /// `ScheduleDetailScreen` 의 `feed` 와 같다 — 예정이면 잠그고, 완료인데 목록을 아직 못 받았으면 흐리게
    /// 자리를 지키고(빼면 완료를 누르는 순간 아래 줄이 출렁인다), 받았는데 없으면 뺀다.
    var feedShare: FeedShare {
        guard canWrite, let detail else { return .hidden }
        if !detail.isCompleted { return .locked }
        guard let ids = postableIds else { return .checking }
        return ids.contains(detail.id) ? .ready : .hidden
    }

    init(scheduleId: Int, roomId: Int? = nil) {
        self.roomId = roomId
        self.scheduleId = scheduleId
    }

    func load(env: AppEnvironment, guest: GuestStore) async {
        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            // 게스트 플랜은 로컬 저장소에서 찾는다 (웹 getGuestScheduleList 대응).
            isGuest = true
            loading = false
            if let item = guest.findSchedule(id: scheduleId) {
                detail = ScheduleDetail(
                    id: item.id,
                    title: item.title,
                    categoryName: item.categoryName,
                    payType: item.payType?.rawValue,
                    amount: item.amount,
                    startDate: item.startDate,
                    location: item.location,
                    locationLat: item.locationLat,
                    locationLng: item.locationLng,
                    memo: item.memo,
                    addCategoryNameList: item.addCategoryNameList ?? [],
                    status: item.status?.rawValue
                )
            } else {
                errorMessage = "플랜 정보를 불러오지 못했습니다."
            }
            return
        }

        isGuest = false
        loading = true
        permission = nil
        errorMessage = nil
        defer { loading = false }

        do {
            let me = JWTDecoder.planUserId(from: token)
            let rooms: RoomList = try await env.api.send(Endpoint.roomList())
            var resolved = roomId ?? env.boundRoomId
            if resolved == nil { let user: PlanUser = try await env.api.send(Endpoint.user()); resolved = user.roomId }
            roomId = resolved
            couple = CoupleChatRules.pick(rooms.list, myId: me)
            permission = rooms.list.first { $0.roomId == resolved }.flatMap { BoundRoom.myPermission(in: $0, planUserId: me) }
            if permission == nil, let user: PlanUser = try? await env.api.send(Endpoint.user()), user.roomId == resolved {
                permission = user.members?.first { $0.planUserId.lowercased() == me?.lowercased() }?.permission
            }
            /*
              방이 정해지지 않고 들어온 **내 개인 플랜**이면 방장이다(Android `resolveAccess` — 내 전체 목록에 있으면 OWNER).
              예전에는 방 멤버 목록에서만 권한을 찾아, 방이 없는 혼자 쓰는 사람은 자기 일정 상세에 `완료로 표시` ·
              `수정하기` · `삭제` 가 하나도 없었다(2026-10-28 iOS QA DET-01, 새 계정).
            */
            if permission == nil, roomId == nil || roomId == resolved, await ownsPersonalSchedule(env: env) {
                permission = .owner
            }
            // 화면이 로딩 카드를 직접 그리므로 전역 오버레이는 띄우지 않는다.
            detail = try await env.api.send(
                Endpoint.schedule(id: scheduleId),
                decoding: ScheduleDetail.self
            )
            if detail?.isCompleted == true, canWrite { await loadPostables(env: env) } else { postableIds = nil }
        } catch let error as APIError {
            // 401 의 토큰 정리·재로그인 안내는 APIClient 가 공통으로 맡는다.
            // 여기서는 화면을 되돌리기 위한 플래그만 세운다.
            errorMessage = error.errorDescription
            sessionExpired = error.requiresReauthentication
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 내 개인 목록(`/plan/schedule/list`, 방 없음)에 이 일정이 있는가 — 모든 쪽을 넘겨 본다(달력 보드와 같은 길)
    private func ownsPersonalSchedule(env: AppEnvironment) async -> Bool {
        var pages = SchedulePages(), page = 1
        while page <= 100 {
            guard let result: SchedulePage = try? await env.api.send(Endpoint.allSchedules(roomId: nil, page: page)) else { return false }
            if result.list.contains(where: { $0.id == scheduleId }) { return true }
            guard let done = try? pages.append(result), !done else { return false }
            page += 1
        }
        return false
    }

    /// 안드로이드 `FeedViewModel.loadPostables` — 못 받으면 빈 목록(= 피드 줄을 뺌)으로 둔다.
    func loadPostables(env: AppEnvironment) async {
        postableIds = nil
        if let page = try? await env.api.send(Endpoint.feedPostable(), decoding: PostablePage.self) {
            postableIds = Set(page.list.map(\.scheduleId))
        } else {
            postableIds = []
        }
    }

    /// 완료로 표시 · 예정으로 되돌리기 — 안드로이드 `ScheduleDetailViewModel.toggleStatus`.
    func toggleStatus(env: AppEnvironment) async {
        guard let current = detail, !statusPending, !isGuest, canWrite else { return }
        let toCompleted = !current.isCompleted
        statusPending = true
        do {
            let response = try await env.api.sendRaw(
                Endpoint.updateScheduleStatus(id: current.id, status: toCompleted ? .completed : .normal)
            )
            detail?.status = toCompleted ? "COMPLETED" : "NORMAL"
            // 완료일 때 받은 isPaid(계산값, 늘 true)를 그대로 두면 되돌린 화면이 `예정 · 결제함` 이 된다(Android 7523938)
            detail?.isPaidRaw = PlanRules.isPaidAfterStatusChange(
                responseIsPaid: StatusChangeResult.isPaid(fromEnvelope: response.body), toCompleted: toCompleted, before: current.isPaidRaw)
            statusPending = false
            if toCompleted { await loadPostables(env: env) } else { postableIds = nil }
        } catch {
            statusPending = false
            if case .http(let status, _) = error as? APIError, status == 404 {
                errorMessage = "삭제되었거나 찾을 수 없는 일정이에요."
            } else {
                errorMessage = "상태를 바꾸지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    func delete(env: AppEnvironment, guest: GuestStore) async {
        guard canWrite, let id = detail?.id, !deleting else { return }

        if isGuest {
            guest.deleteSchedule(id: id)
            deleted = true
            return
        }

        deleting = true
        defer { deleting = false }

        do {
            // DELETE 는 200 + 빈 본문으로 온다. 본문 파싱 실패로 성공을 뒤집으면 안 된다.
            try await env.api.sendIgnoringData(Endpoint.deleteSchedule(id: id))
            deleted = true
        } catch {
            // 서버 응답 원문을 그대로 노출하지 않는다 (웹·안드로이드와 동일).
            if case .http(let status, _) = error as? APIError, status == 403 {
                errorMessage = "이 플랜을 삭제할 권한이 없습니다."
            } else {
                errorMessage = "삭제하지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
    }
}
