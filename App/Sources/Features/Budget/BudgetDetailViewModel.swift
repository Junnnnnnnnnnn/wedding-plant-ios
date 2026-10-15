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

    private(set) var roomId: String?
    private let roomIdFromArg: String?

    /// 필터 조합별 목록 캐시 — 탭을 오갈 때마다 전량을 다시 받지 않는다 (웹과 동일)
    private var cache: [String: [ScheduleItem]] = [:]

    init(roomId: String? = nil) {
        self.roomIdFromArg = roomId
        self.roomId = roomId
    }

    // MARK: - 파생 값

    var initialCapital: Double { detail?.initialCapital ?? 0 }
    var plannedTotal: Double { detail?.plannedUseAmount ?? 0 }
    var usedTotal: Double { detail?.usedAmount ?? 0 }
    var remaining: Double { detail?.remaining ?? 0 }
    var savings: Double { detail?.savings ?? 0 }
    var usedPercent: Int { detail?.usedPercent ?? 0 }

    /// 도넛이 그릴 구간. 계산은 Core 가 한다.
    var donutSegments: BudgetDonutSegments {
        detail.map(BudgetDonutSegments.init) ?? BudgetDonutSegments(capital: 0, used: 0, planned: 0)
    }

    /// usedAmount 큰 순 내림차순 (웹·안드로이드 `sortedByDescending` 과 동일).
    ///
    /// **같은 금액끼리는 서버가 준 순서를 지킨다**(안정 정렬). 예전에는 이름순으로 갈라
    /// 안드로이드(웨딩홀 · 본식스냅 · 스튜디오 · 신혼여행 · 예물 …)와 줄 순서가 달랐다.
    /// 게스트 쪽도 처음 나온 순서로 묶어(`loadGuest`) 새로고침마다 바뀌지 않는다.
    var sortedCategories: [CategoryChartItem] {
        categories.enumerated()
            .sorted { $0.element.used == $1.element.used ? $0.offset < $1.offset : $0.element.used > $1.element.used }
            .map(\.element)
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
        // 다시 받을 때는 본문을 뼈대로 바꾸지 않는다(안드로이드와 같음) — 결제창에서 돌아올 때도
        // 여기가 불려, 엑셀 버튼의 요금제 화면 뒤에서 본문이 깜빡였다.
        let hadDetail = detail != nil
        loading = !hadDetail
        errorMessage = nil
        defer { loading = false }

        // roomId 를 알아야 나머지 요청 경로가 정해지므로 먼저 받아온다.
        let user = try? await env.api.send(Endpoint.user(), decoding: PlanUser.self)
        // roomId: 인자 우선 → **귀속된 방** → /plan/user 의 roomId.
        //
        // 귀속을 빠뜨리면 배우자가 이 화면에서만 자기 개인 예산(빈 값)을 본다 —
        // 웹이 `/main` 에만 리다이렉트를 걸었다가 `/calendar`·`/budget-detail` 로
        // 샌 것과 같은 구멍이다.
        if let arg = roomIdFromArg, !arg.trimmingCharacters(in: .whitespaces).isEmpty {
            roomId = arg
        } else if let bound = env.boundRoomId {
            roomId = String(bound)
        } else {
            roomId = user?.roomId.map(String.init)
        }

        async let detailTask = try? env.api.send(
            Endpoint.amountDetail(roomId: roomId),
            decoding: AmountDetail.self
        )
        async let chartTask = try? env.api.send(
            Endpoint.amountCategoryChart(roomId: roomId),
            decoding: CategoryChartPage.self
        )
        async let listTask = fetchList(env: env)

        let fetchedDetail = await detailTask
        let chart = await chartTask
        let list = await listTask
        // 다시 받기에 실패하면 직전 값을 둔다(안드로이드와 같음).
        detail = fetchedDetail ?? detail
        if let chart { categories = chart.list }
        if let list { items = list }
        // 문구는 안드로이드 `BudgetDetailViewModel` 과 같다.
        if detail == nil { errorMessage = "예산 정보를 불러오지 못했습니다." }
    }

    /// 웹: 비로그인은 로컬 게스트 플랜으로 같은 화면을 계산해 보여 준다 (블러 처리됨).
    private func loadGuest(guest: GuestStore) {
        let all = guest.schedules
        // 웹: `Number(weddingData.budget) || 1000` — 예산이 없으면 1000만원으로 본다
        let initial = (guest.budget ?? 0) > 0 ? (guest.budget ?? 0) : 1000
        // 게스트도 같은 규칙으로 센다 — 결제했으면 사용, 아니면 예정(안드로이드 결제 축)
        let planned = all.filter { !$0.isPaid }.reduce(0) { $0 + ($1.amount ?? 0) }
        let used = all.filter { $0.isPaid }.reduce(0) { $0 + ($1.amount ?? 0) }

        // 처음 나온 순서로 묶는다(안드로이드 `groupBy`) — Dictionary 는 순서가 매번 달라진다.
        var order: [String] = []
        var grouped: [String: [ScheduleItem]] = [:]
        for item in all {
            let name = item.categoryName.isEmpty ? "Others" : item.categoryName
            if grouped[name] == nil { order.append(name) }
            grouped[name, default: []].append(item)
        }
        categories = order.map { name in
            let list = grouped[name] ?? []
            return CategoryChartItem(
                categoryName: name,
                totalAmount: list.reduce(0) { $0 + ($1.amount ?? 0) },
                usedAmount: list.filter { $0.isPaid }.reduce(0) { $0 + ($1.amount ?? 0) }
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
        // 탭·카테고리를 빨리 바꾸면 늦게 온 응답이 지금 탭 목록을 덮었다 — 마지막 요청의 답만 쓴다.
        listSeq += 1
        let seq = listSeq
        guard let list = await fetchList(env: env), seq == listSeq else { return }
        items = list
    }

    private var listSeq = 0

    private func filterGuest(_ all: [ScheduleItem]) -> [ScheduleItem] {
        all.filter { item in
            // 탭도 결제 기준이다. 미리 낸 계약금은 "사용" 에 있어야 한다.
            let tabOk = tab == .planned ? !item.isPaid : item.isPaid
            let categoryOk = selectedCategory == nil || item.categoryName == selectedCategory
            return tabOk && categoryOk
        }
    }

    /// - Returns: 못 받았으면 nil — **실패를 빈 목록으로 캐시하지 않는다**(돌아오면 다시 받게).
    ///
    /// **서버에 상태로 거르지 않는다**(안드로이드와 같음). 예정/사용은 결제 기준이라 일정 상태로는
    /// 못 가른다 — 미리 낸 계약금은 예정 상태인데 "사용" 에 있어야 한다. 둘 다 받아 앱이 가른다.
    private func fetchList(env: AppEnvironment) async -> [ScheduleItem]? {
        let key = "\(roomId ?? "")|\(tab.rawValue)|\(selectedCategory ?? "")"
        if let cached = cache[key] { return cached }

        func request(_ status: Endpoint.ScheduleListStatus) -> HTTPRequest {
            var request = Endpoint.scheduleList(status: status, roomId: roomId)
            if let selectedCategory { request.query["categoryName"] = selectedCategory }
            return request
        }
        async let normal = try? env.api.send(request(.normal), decoding: SchedulePage.self)
        async let completed = try? env.api.send(request(.completed), decoding: SchedulePage.self)
        // 하나라도 못 받았으면 절반만 찬 목록을 만들지 않는다.
        guard let normalPage = await normal, let completedPage = await completed else { return nil }

        let wantPaid = tab == .used
        // 탭 목록 전체가 **시작일 내림차순 하나**다(웹·안드로이드). 상태별로 이어 붙이면
        // '예정 묶음 → 완료 묶음' 순서가 되어 날짜가 뒤섞인다. 날짜 없는 것은 뒤로.
        let list = (normalPage.list + completedPage.list)
            .filter { $0.isPaid == wantPaid }
            .enumerated()
            .sorted { lhs, rhs in
                let a = KstDate(dateString: lhs.element.startDate ?? "")
                let b = KstDate(dateString: rhs.element.startDate ?? "")
                switch (a, b) {
                case let (a?, b?): return a == b ? lhs.offset < rhs.offset : b < a
                case (nil, nil): return lhs.offset < rhs.offset
                case (nil, _): return false
                case (_, nil): return true
                }
            }
            .map(\.element)
        cache[key] = list
        return list
    }
}
