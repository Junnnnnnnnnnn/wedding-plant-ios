import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/main/page.tsx` 의 데이터 로딩 부분 포팅.
///
/// 웹은 한 파일에 UI·상태·fetch 가 섞여 있지만, 여기서는 안드로이드와 같이 상태를 분리한다.
/// View 는 그리기만 한다.
@MainActor
final class MainViewModel: ObservableObject {

    enum Tab {
        case planned
        case completed
    }

    @Published var loading = true
    @Published var name = ""
    @Published var weddingDate: KstDate?
    @Published var members: [Member] = []
    /// 이 방에서 내가 읽기 전용인지. 캘린더의 플랜 추가 버튼을 감출지 판단에 쓴다.
    @Published var readOnly = false
    @Published var totalBudget = 0
    @Published var usedBudget = 0
    @Published var remainingBudget = 0
    @Published var tab: Tab = .planned
    /// 정렬. 바꾸면 서버에서 다시 받아온다 (정렬은 백엔드가 한다).
    @Published var sort: SortOption = .default
    @Published var planned: [ScheduleItem] = []
    @Published var completed: [ScheduleItem] = []
    @Published var plannedTotal = 0
    @Published var completedTotal = 0
    @Published var togglingIds: Set<Int> = []
    @Published var errorMessage: String?
    /// 토큰이 만료돼 로그인 화면으로 돌려보내야 하는 상태
    @Published var sessionExpired = false
    @Published var isGuest = false

    private var roomId: String?

    /// 플랜 추가 화면에 그대로 넘겨야 같은 방에 저장된다.
    /// 빼면 개인 스코프로 저장돼 200 인데 목록에 영영 안 나온다.
    var roomIdValue: Int? { roomId.flatMap(Int.init) }

    var visibleList: [ScheduleItem] {
        tab == .planned ? planned : completed
    }

    /// 웹: 전체 플랜이 0개일 때만 "텅~"
    var isCompletelyEmpty: Bool {
        planned.isEmpty && completed.isEmpty
    }

    var dDayLabel: String {
        PlanRules.dDayLabel(weddingDate: weddingDate)
    }

    var usagePercent: Int {
        PlanRules.budgetUsagePercent(total: Double(totalBudget), used: Double(usedBudget))
    }

    var usagePercentClamped: Int {
        PlanRules.budgetUsagePercentClamped(total: Double(totalBudget), used: Double(usedBudget))
    }

    // MARK: - 로딩

    func load(env: AppEnvironment, guest: GuestStore) async {
        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            // 비로그인(게스트): 로컬에 저장된 값만 보여준다. API 호출 없음 (웹과 동일).
            loading = false
            isGuest = true
            name = guest.name
            weddingDate = guest.weddingDate
            totalBudget = guest.budget ?? 0
            usedBudget = 0
            remainingBudget = guest.budget ?? 0
            planned = []
            completed = []
            plannedTotal = 0
            completedTotal = 0
            return
        }

        isGuest = false
        loading = true
        defer { loading = false }

        do {
            let user = try await env.api.send(Endpoint.user(), decoding: PlanUser.self)
            roomId = user.roomId.map(String.init)
            name = user.name ?? ""
            weddingDate = user.weddingDate.flatMap { KstDate(dateString: $0) }
            members = user.members ?? []
            let token = await env.tokenStore.currentToken()
            let planUserId = token.flatMap { JWTDecoder.planUserId(from: $0) }
            readOnly = PlanRules.isReadOnly(members: members, planUserId: planUserId)
        } catch let error as APIError {
            if error.requiresReauthentication {
                sessionExpired = true
            } else {
                errorMessage = error.errorDescription
            }
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // 금액과 두 탭은 서로 독립이라 동시에 받는다.
        // 개별 실패는 화면 전체를 막지 않고 해당 영역만 비운다.
        //
        // 방에 속한 사용자는 방 기준 금액을 봐야 한다 (안드로이드와 동일한 분기).
        let amountEndpoint = roomId.map { Endpoint.roomTotalAmount(roomId: $0) } ?? Endpoint.totalAmount()
        async let amountTask = env.api.send(amountEndpoint, decoding: TotalAmount.self)
        async let plannedTask = env.api.send(
            Endpoint.scheduleList(
                status: .normal,
                roomId: roomId,
                sortColumn: sort.column.parameter,
                descending: sort.descending
            ),
            decoding: SchedulePage.self
        )
        async let completedTask = env.api.send(
            Endpoint.scheduleList(
                status: .completed,
                roomId: roomId,
                sortColumn: sort.column.parameter,
                descending: sort.descending
            ),
            decoding: SchedulePage.self
        )

        let amount = try? await amountTask
        let plannedPage = try? await plannedTask
        let completedPage = try? await completedTask

        if let amount {
            totalBudget = amount.totalAmount ?? 0
            usedBudget = amount.usedAmount ?? 0
            remainingBudget = amount.remainingAmount ?? ((amount.totalAmount ?? 0) - (amount.usedAmount ?? 0))
        }
        // 서버가 정렬해 주지만, 날짜 미정 항목을 뒤로 미는 보정은 클라이언트가 한다.
        if let plannedPage {
            planned = ScheduleSort.sorted(plannedPage.list, by: sort.column, descending: sort.descending)
            plannedTotal = plannedPage.total
        }
        if let completedPage {
            completed = ScheduleSort.sorted(completedPage.list, by: sort.column, descending: sort.descending)
            completedTotal = completedPage.total
        }
    }

    /// 정렬을 바꾸고 목록을 다시 받아온다.
    func setSort(_ option: SortOption, env: AppEnvironment, guest: GuestStore) async {
        guard option != sort else { return }
        sort = option
        await load(env: env, guest: guest)
    }

    // MARK: - 체크박스 토글

    /// 웹 `handleToggleCheck()` — 계획 중 <-> 완료 전환.
    /// 낙관적으로 먼저 리스트를 옮기고, 실패하면 되돌린다.
    func toggle(_ item: ScheduleItem, env: AppEnvironment) async {
        if isGuest {
            errorMessage = "로그인하면 플랜을 완료 처리할 수 있어요."
            return
        }
        guard !togglingIds.contains(item.id) else { return }

        let toCompleted = !(item.status?.isCompleted ?? false)
        let snapshot = (planned, completed, plannedTotal, completedTotal)

        move(item, toCompleted: toCompleted)
        togglingIds.insert(item.id)
        defer { togglingIds.remove(item.id) }

        do {
            try await env.api.sendIgnoringData(
                Endpoint.updateScheduleStatus(id: item.id, status: toCompleted ? .completed : .normal)
            )
        } catch {
            // 롤백
            (planned, completed, plannedTotal, completedTotal) = snapshot
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func move(_ item: ScheduleItem, toCompleted: Bool) {
        var moved = item
        moved.status = toCompleted ? .completed : ScheduleStatus(rawValue: "NORMAL")

        if toCompleted {
            planned.removeAll { $0.id == item.id }
            completed.insert(moved, at: 0)
            plannedTotal = max(plannedTotal - 1, 0)
            completedTotal += 1
        } else {
            completed.removeAll { $0.id == item.id }
            planned.insert(moved, at: 0)
            completedTotal = max(completedTotal - 1, 0)
            plannedTotal += 1
        }
    }
}
