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
    /// 목록을 **한 번이라도** 받았는지.
    ///
    /// 뼈대를 낼지 빈 상태를 낼지 가르는 값이다. `loading` 만 보면 다시 받을 때마다
    /// 화면이 통째로 뼈대로 돌아가고, 안 보면 **받기 전에 "없다" 고 말하게 된다.**
    @Published var listLoaded = false
    @Published var name = ""
    @Published var weddingDate: KstDate?
    /// 예식장 이름. 머리 면에서 날짜 옆에 붙는다. 게스트는 저장할 곳이 없어 늘 빈 값이다.
    @Published var weddingVenue = ""
    @Published var members: [Member] = []
    /// 이 방에서 내가 읽기 전용인지. 캘린더의 플랜 추가 버튼을 감출지 판단에 쓴다.
    @Published var readOnly = false
    @Published var totalBudget = 0
    @Published var usedBudget = 0
    @Published var remainingBudget = 0
    @Published var tab: Tab = .planned
    /// 정렬. 바꾸면 서버에서 다시 받아온다 (정렬은 백엔드가 한다).
    /// **다가오는 순**이 기본이다(웹 main C안에서 `date_desc` → `date_asc`).
    /// 최신순이면 지난 일정이 목록 맨 아래에 묻힌다. 폰 홈에는 정렬 버튼이 없어
    /// 사실상 이 값이 고정이다 — `SortOption.default`(최신순)와 다른 이유다.
    @Published var sort: SortOption = .dateAsc
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
    private var planUserId: String?

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

    /// 머리 면의 두 줄 문장.
    var dDaySentence: (String, String) {
        PlanRules.dDaySentence(weddingDate: weddingDate)
    }

    /// 방을 보고 있는지. `roomId` 가 붙어 있으면 그 방 기준으로 읽는다.
    var isRoomView: Bool { roomId?.isEmpty == false }

    /// 내 권한. 방을 보고 있지 않으면 알 수 없다(`nil`).
    var myPermission: PlanPermission? {
        guard isRoomView, let planUserId else { return nil }
        return members.first { $0.planUserId == planUserId }?.permission
    }

    /// 쓰기가 가능한지. `READ` 면 추가 버튼을 감춘다 —
    /// **눌러야만 실패를 아는 버튼은 두지 않는다.**
    var canWrite: Bool { !readOnly }

    /// 머리글에 낼 이름 — 웹 `coupleDisplayName`.
    ///
    /// **커플 플랜이면 두 사람을 함께 적는다**(`방장 · 배우자`). 귀속된 뒤에는 이
    /// 플랜이 둘의 것이라, 방장 이름만 띄우면 들어온 사람은 계속 남의 플랜에
    /// 얹혀 있는 것처럼 읽힌다.
    var displayName: String {
        guard isRoomView else { return name }
        let owner = members.first { $0.permission == .owner }?.name
            .trimmingCharacters(in: .whitespaces) ?? ""
        let spouse = members.first { $0.permission.rawValue == "SPOUSE" }?.name
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !owner.isEmpty, !spouse.isEmpty else { return name }
        return "\(owner) · \(spouse)"
    }

    /// 머리 면의 작은 아바타. 최대 두 개.
    ///
    /// 이름을 `·` 로 쪼갠다("지수 · 현우" → 지, 현). 왕관·하트 배지는 달지 않는다 —
    /// 26pt 위에서 안 읽히고, 누가 방장인지는 멤버 목록이 말한다.
    var headerInitials: [String] {
        displayName
            .split(whereSeparator: { "·・,".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(2)
            .map { String($0.prefix(1)) }
    }

    /// 방에 배우자가 있는지.
    var hasSpouse: Bool {
        members.contains { $0.permission == .spouse }
    }

    /// 초대 띠를 낼지 — 웹 `showSoloBanner`.
    ///
    /// - Important: **`myPermission` 만으로 판단하면 안 된다.** 내 플랜은 `roomId`
    ///   가 아직 없을 수 있고(`isRoomView` false), 그러면 권한이 비어 "OWNER 가
    ///   아님" 으로 떨어져 띠가 **영영 안 뜬다.**
    ///   "방을 보고 있지 않으면 내 플랜" 이 맞다.
    ///
    /// 남의 플랜을 보는 중이면 방장이 아니므로 내지 않는다 — 남의 플랜에
    /// "부르기" 가 뜨면 안 된다.
    ///
    /// **자랑하기(`canBrag`)와 규칙이 갈리는 지점이다** — 배우자를 지정하는 일은
    /// 방장만 하지만, 자기 결혼을 자랑하는 건 둘 다 한다.
    var showSoloBanner: Bool {
        guard !isGuest, listLoaded, !hasSpouse else { return false }
        guard isRoomView else { return true }
        return myPermission == .owner
    }

    /// 자랑하기 토글을 낼지 — 웹 `canBrag`.
    ///
    /// 남의 방·공유 뷰면 자랑할 대상이 아니다. **배우자도 자랑할 수 있다** —
    /// 귀속된 뒤에는 둘의 플랜이다. 방장만 허용하면 들어온 사람 화면에서 그 칸이
    /// 통째로 사라진다.
    ///
    /// - Important: **`roomId` 유무로 판단하지 말 것.** 로그인하면 내 플랜에도 방이
    ///   생겨 `isRoomView` 가 참이 되므로, 그 조건으로는 토글이 영영 안 뜬다.
    ///   초대 띠(`showSoloBanner`)와 같은 규칙이다.
    var canBrag: Bool {
        guard !isGuest, listLoaded else { return false }
        guard isRoomView else { return true }
        guard let permission = myPermission else { return true }
        return permission == .owner || permission == .spouse
    }

    /// 홈의 두 묶음 — `이번 달에 할 일` / `그 다음`.
    ///
    /// 카테고리 칩을 걷고 **계획 중 목록을 시간으로만** 가른다. 완료한 것을 되짚거나
    /// 카테고리로 좁혀 보는 일은 "전체"(캘린더)가 맡는다.
    func timeBuckets(today: KstDate) -> (thisMonth: [ScheduleItem], later: [ScheduleItem]) {
        var now: [ScheduleItem] = []
        var later: [ScheduleItem] = []
        for item in planned {
            if PlanRules.isThisMonthOrPast(startDate: item.startDate, today: today) {
                now.append(item)
            } else {
                later.append(item)
            }
        }
        return (now, later)
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
            listLoaded = true
            return
        }

        isGuest = false
        loading = true
        defer { loading = false }

        do {
            let user = try await env.api.send(Endpoint.user(), decoding: PlanUser.self)
            let token = await env.tokenStore.currentToken()
            planUserId = token.flatMap { JWTDecoder.planUserId(from: $0) }

            if let bound = env.boundRoomPlan {
                // **귀속된 방이 내 플랜이다.** 부부는 결혼식을 두 번 하지 않는다 —
                // 홈·캘린더·예산이 전부 이 방을 본다. 개인 플랜은 화면에서 내려갈
                // 뿐 지워지지 않는다(방에서 나가면 다시 뜬다).
                roomId = String(bound.roomId)
                name = bound.ownerName
                weddingVenue = ""
                weddingDate = KstDate(dateString: bound.weddingDate)
                members = bound.members
            } else {
                roomId = user.roomId.map(String.init)
                name = user.name ?? ""
                weddingVenue = user.weddingVenue ?? ""
                weddingDate = user.weddingDate.flatMap { KstDate(dateString: $0) }
                members = user.members ?? []
            }
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

        // 한 번이라도 받았으면 다시 받을 때 화면을 뼈대로 되돌리지 않는다.
        if plannedPage != nil || completedPage != nil { listLoaded = true }
    }

    /// 받기 전에 "없다" 고 말하지 않기 위한 값. 뼈대를 낼 조건이다.
    var planLoading: Bool { loading && !listLoaded }

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
