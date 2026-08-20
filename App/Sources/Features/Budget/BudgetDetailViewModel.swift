import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/budget-detail/page.tsx` 이식.
///
/// 초기 자본 / 예정 / 사용 요약 + 카테고리별 막대 + 예정·사용 탭 목록.
/// 그래프의 카테고리를 누르면 목록도 그 카테고리로 좁혀진다.
@MainActor
final class BudgetDetailViewModel: ObservableObject {

    enum Tab: String, CaseIterable, Identifiable {
        case planned
        case used

        var id: String { rawValue }
        var label: String { self == .planned ? "예정" : "사용" }
    }

    @Published var loading = true
    @Published var isGuest = false
    @Published var detail: AmountDetail?
    @Published var categories: [CategoryChartItem] = []
    @Published var items: [ScheduleItem] = []
    @Published var tab: Tab = .planned
    @Published var selectedCategory: String?
    @Published var errorMessage: String?

    private var roomId: String?
    private let roomIdFromArg: String?

    /// 필터 조합별 목록 캐시 — 탭을 오갈 때마다 전량을 다시 받지 않는다 (웹과 동일)
    private var cache: [String: [ScheduleItem]] = [:]

    init(roomId: String? = nil) {
        self.roomIdFromArg = roomId
        self.roomId = roomId
    }

    // MARK: - 파생 값

    var initialCapital: Int { detail?.initialCapital ?? 0 }
    var plannedTotal: Int { detail?.plannedUseAmount ?? 0 }
    var usedTotal: Int { detail?.usedAmount ?? 0 }
    var remaining: Int { detail?.remaining ?? 0 }
    var savings: Int { detail?.savings ?? 0 }
    var usedPercent: Int { detail?.usedPercent ?? 0 }

    /// usedAmount 큰 순 내림차순 (웹과 동일).
    ///
    /// 같은 금액끼리는 이름순으로 고정한다 — 게스트 쪽은 Dictionary 로 묶어서
    /// 순서가 매번 달라지는데, 그러면 화면이 새로고침마다 바뀌어 보인다.
    var sortedCategories: [CategoryChartItem] {
        categories.sorted {
            $0.used == $1.used ? $0.categoryName < $1.categoryName : $0.used > $1.used
        }
    }

    // MARK: - 로딩

    func load(env: AppEnvironment, guest: GuestStore) async {
        cache.removeAll()

        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            loadGuest(guest: guest)
            return
        }

        isGuest = false
        loading = true
        errorMessage = nil
        defer { loading = false }

        // roomId 를 알아야 나머지 요청 경로가 정해지므로 먼저 받아온다.
        let user = try? await env.api.send(Endpoint.user(), decoding: PlanUser.self)
        // roomId: 인자 우선, 없으면 /plan/user 의 roomId (웹과 동일)
        if let arg = roomIdFromArg, !arg.trimmingCharacters(in: .whitespaces).isEmpty {
            roomId = arg
        } else {
            roomId = user?.roomId.map(String.init)
        }

        async let detailTask = env.api.send(
            Endpoint.amountDetail(roomId: roomId),
            decoding: AmountDetail.self
        )
        async let chartTask = env.api.send(
            Endpoint.amountCategoryChart(roomId: roomId),
            decoding: CategoryChartPage.self
        )

        do {
            // 요약이 없으면 화면에 보여줄 게 없다. 막대·목록은 실패해도 빈 채로 그린다.
            let fetchedDetail = try await detailTask
            let chart = try? await chartTask

            detail = fetchedDetail
            categories = chart?.list ?? []
            items = await fetchList(env: env)
        } catch {
            // 문구는 웹과 동일하게 맞춘다.
            errorMessage = "데이터를 불러오지 못했습니다."
            detail = nil
            categories = []
            items = []
        }
    }

    /// 웹: 비로그인은 로컬 게스트 플랜으로 같은 화면을 계산해 보여 준다 (블러 처리됨).
    private func loadGuest(guest: GuestStore) {
        let all = guest.schedules
        // 웹: `Number(weddingData.budget) || 1000` — 예산이 없으면 1000만원으로 본다
        let initial = (guest.budget ?? 0) > 0 ? (guest.budget ?? 0) : 1000
        let planned = all.filter { !($0.status?.isCompleted ?? false) }.reduce(0) { $0 + ($1.amount ?? 0) }
        let used = all.filter { $0.status?.isCompleted ?? false }.reduce(0) { $0 + ($1.amount ?? 0) }

        let grouped = Dictionary(grouping: all) { item in
            item.categoryName.isEmpty ? "Others" : item.categoryName
        }
        categories = grouped.map { name, list in
            CategoryChartItem(
                categoryName: name,
                totalAmount: list.reduce(0) { $0 + ($1.amount ?? 0) },
                usedAmount: list.filter { $0.status?.isCompleted ?? false }.reduce(0) { $0 + ($1.amount ?? 0) }
            )
        }

        detail = AmountDetail(
            initialCapital: initial,
            totalPlannedAndUsedAmount: planned + used,
            plannedUseAmount: planned,
            usedAmount: used
        )
        // 웹은 첫 진입에서만 전체 목록을 그대로 보여주고 탭을 바꿔야 걸러진다(웹 쪽 버그).
        // 여기서는 처음부터 현재 탭 기준으로 걸러 "예정" 탭에 완료 항목이 섞이지 않게 한다.
        items = filterGuest(all)
        isGuest = true
        loading = false
        errorMessage = nil
    }

    // MARK: - 탭·필터

    func setTab(_ next: Tab, env: AppEnvironment, guest: GuestStore) async {
        guard tab != next else { return }
        tab = next
        await reloadList(env: env, guest: guest)
    }

    /// 같은 카테고리를 다시 누르면 해제 (웹 `handleCategoryToggle`)
    func toggleCategory(_ name: String, env: AppEnvironment, guest: GuestStore) async {
        selectedCategory = (selectedCategory == name) ? nil : name
        await reloadList(env: env, guest: guest)
    }

    func clearCategory(env: AppEnvironment, guest: GuestStore) async {
        guard selectedCategory != nil else { return }
        selectedCategory = nil
        await reloadList(env: env, guest: guest)
    }

    private func reloadList(env: AppEnvironment, guest: GuestStore) async {
        if isGuest {
            items = filterGuest(guest.schedules)
            return
        }
        items = await fetchList(env: env)
    }

    private func filterGuest(_ all: [ScheduleItem]) -> [ScheduleItem] {
        all.filter { item in
            let completed = item.status?.isCompleted ?? false
            let tabOk = tab == .planned ? !completed : completed
            let categoryOk = selectedCategory == nil || item.categoryName == selectedCategory
            return tabOk && categoryOk
        }
    }

    private func fetchList(env: AppEnvironment) async -> [ScheduleItem] {
        let key = "\(roomId ?? "")|\(tab.rawValue)|\(selectedCategory ?? "")"
        if let cached = cache[key] { return cached }

        var request = Endpoint.scheduleList(
            status: tab == .planned ? .normal : .completed,
            roomId: roomId
        )
        if let selectedCategory {
            request.query["categoryName"] = selectedCategory
        }

        let page = try? await env.api.send(request, decoding: SchedulePage.self)
        let list = page?.list ?? []
        cache[key] = list
        return list
    }
}
