import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/calendar/page.tsx` 의 데이터 로딩 — 안드로이드 `ui/calendar/CalendarViewModel.kt` 와 짝.
///
/// 격자가 42칸이라 앞뒤 달 날짜도 같이 보인다. 그래서 **앞·현재·다음 달(+ 고른 날의 달)을
/// 한꺼번에 받아** 하루 단위로 합친다 (``CalendarGrid/monthsToFetch(cursor:selected:)``).
@MainActor
final class CalendarViewModel: ObservableObject {

    /// 폰의 달력 ↔ 보드 (시안 C안 02).
    enum MobileView { case calendar, board }

    /// 화면에 보이는 달의 1일.
    @Published private(set) var cursor: KstDate = KstDate.today().firstOfMonth
    /// "YYYY-MM-DD" → 그 날의 플랜들
    @Published private(set) var byDay: [String: [CalendarPlanItem]] = [:]
    @Published private(set) var loading = true
    /// 한 번이라도 받았나(웹 `calendarLoaded`). 그 전에는 그날 목록이 "비어 있다" 대신 뼈대를 낸다.
    @Published private(set) var loadedOnce = false
    @Published private(set) var calendarError: String?
    @Published private(set) var listError: String?
    /// 처음에는 **보드**(Android 8c1068b `view = MobileView.LIST`, iOS 요청서 02 · 2026-10-28 사용자). 달 한 장이 아니라
    /// 지난 · 다음 · 미정 · 완료 일정이 다 모여 있어 처음 보기에 낫다. 보드는 자기 목록(`upcoming`)을 받는다 — 달력 한 달의
    /// 응답으로 채우면 다른 달 일정이 빠진다.
    @Published private(set) var view: MobileView = .board
    /// 달력 아래 그날 목록의 날짜. **처음부터 오늘**이라 목록이 비지 않는다.
    @Published private(set) var selectedDate: KstDate = KstDate.today()
    /// 보드 뷰 — 전체 일정. 보드를 처음 열 때 받는다.
    @Published private(set) var upcoming: [ScheduleItem] = [] { didSet { boardGroups = CalendarGrid.boardGroups(upcoming) } }
    /// 보드의 달 묶음 — 목록이 바뀔 때 한 번만 짓는다(화면을 그릴 때마다 묶으면 굴릴 때마다 다시 정렬했다, 요청서 08)
    @Published private(set) var boardGroups: [(label: String, items: [ScheduleItem])] = []
    @Published private(set) var upcomingLoaded = false

    /// 읽기 권한이면 추가 버튼을 감춘다. 메인에서 이미 알고 있는 값을 받아 온다.
    let readOnly: Bool

    private let roomId: String?

    /// 늦게 도착한 이전 달 응답이 최신 화면을 덮어쓰지 않도록 세는 순번.
    private var fetchSequence = 0
    private var upcomingSequence = 0
    /// 지금 받아 둔 달들. 고른 날이 이 밖이면 다시 받는다.
    private var loadedMonths: [(year: Int, month: Int)] = []

    init(roomId: String? = nil, readOnly: Bool = false) {
        self.roomId = roomId
        self.readOnly = readOnly
    }

    var year: Int { cursor.year }
    var month: Int { cursor.month }
    var title: String { "\(cursor.year)년 \(cursor.month)월" }

    var grid: [KstDate] { CalendarGrid.build(cursor: cursor) }

    var monthTotals: CalendarGrid.MonthTotals {
        CalendarGrid.monthTotals(byDay: byDay, year: cursor.year, month: cursor.month)
    }

    /// 보고 있는 뷰의 오류(안드로이드 `UiState.error`).
    var error: String? { view == .board ? listError : calendarError }

    func plans(on date: KstDate) -> [CalendarPlanItem] {
        byDay[date.dateString] ?? []
    }

    func inCurrentMonth(_ date: KstDate) -> Bool {
        date.year == cursor.year && date.month == cursor.month
    }

    // MARK: - 이동

    func previousMonth(env: AppEnvironment, guest: GuestStore) async {
        cursor = cursor.addingMonths(-1)
        await load(env: env, guest: guest)
    }

    func nextMonth(env: AppEnvironment, guest: GuestStore) async {
        cursor = cursor.addingMonths(1)
        await load(env: env, guest: guest)
    }

    /// 날짜를 누르면 시트를 띄우지 않고 달력 아래 그날 목록이 바뀐다.
    func select(_ date: KstDate, env: AppEnvironment, guest: GuestStore) async {
        selectedDate = date
        if !loadedMonths.contains(where: { $0.year == date.year && $0.month == date.month }) {
            await load(env: env, guest: guest)
        }
    }

    func setView(_ next: MobileView, env: AppEnvironment, guest: GuestStore) async {
        view = next
        if next == .board { await loadUpcoming(env: env, guest: guest) }
    }

    /// 화면에 다시 올 때(상세·추가에서 돌아옴) 보고 있는 뷰를 새로 받는다.
    func refresh(env: AppEnvironment, guest: GuestStore) async {
        await load(env: env, guest: guest)
        if view == .board { await loadUpcoming(env: env, guest: guest) }
    }

    // MARK: - 로딩

    func load(env: AppEnvironment, guest: GuestStore) async {
        fetchSequence += 1
        let sequence = fetchSequence

        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            loadGuest(guest: guest)
            return
        }

        loading = true
        calendarError = nil

        let targets = CalendarGrid.monthsToFetch(cursor: cursor, selected: selectedDate)
        let results = await withTaskGroup(of: Result<CalendarPage, Error>.self) { group in
            for target in targets {
                group.addTask { [roomId, api = env.api] in
                    do {
                        return .success(try await api.send(
                            Endpoint.calendar(year: target.year, month: target.month, roomId: roomId),
                            decoding: CalendarPage.self
                        ))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var collected: [Result<CalendarPage, Error>] = []
            for await result in group { collected.append(result) }
            return collected
        }

        // 더 최신 요청이 시작됐으면 이 응답은 버린다.
        guard sequence == fetchSequence else { return }

        var merged: [String: [CalendarPlanItem]] = [:]
        for result in results {
            switch result {
            case .failure(let error):
                loading = false
                calendarError = (error as? APIError)?.errorDescription ?? error.localizedDescription
                return
            case .success(let page):
                for day in page.list where !day.day.isEmpty {
                    merged[day.day] = day.list
                }
            }
        }
        byDay = merged
        loadedMonths = targets
        loading = false
        loadedOnce = true
    }

    /// 보드 뷰의 데이터. 달력 응답은 그 달만 주는데 보드는 달 경계를 넘어 이어져야 해서
    /// 전체 쪽을 끝까지 읽고, 실패를 빈 목록과 구분한다.
    private func loadUpcoming(env: AppEnvironment, guest: GuestStore) async {
        let token = await env.tokenStore.currentToken()
        guard let token, !token.isEmpty else {
            upcoming = guest.schedules
            upcomingLoaded = true
            return
        }
        upcomingSequence += 1
        let sequence = upcomingSequence
        listError = nil
        do {
            var pages = SchedulePages(), page = 1
            let room = roomId.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            while page <= 100 {
                let result: SchedulePage = try await env.api.send(Endpoint.allSchedules(roomId: room, page: page))
                if try pages.append(result) { break }
                page += 1
            }
            guard sequence == upcomingSequence else { return }
            upcoming = pages.result
            upcomingLoaded = true
        } catch {
            guard sequence == upcomingSequence else { return }
            upcomingLoaded = false
            listError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 비로그인은 로컬 일정만 보여 준다 (웹 `getGuestScheduleList`).
    private func loadGuest(guest: GuestStore) {
        var merged: [String: [CalendarPlanItem]] = [:]
        for item in guest.schedules {
            guard let startDate = item.startDate,
                  let date = KstDate(dateString: startDate)
            else { continue }
            merged[date.dateString, default: []].append(
                CalendarPlanItem(
                    id: item.id,
                    title: item.title,
                    categoryName: item.categoryName,
                    amount: item.amount,
                    // status 를 버리면 완료 표시가 절대 안 뜬다.
                    status: item.status,
                    startTime: item.startTime,
                    isPaidRaw: item.isPaidRaw
                )
            )
        }
        byDay = merged
        loading = false
        loadedOnce = true
    }
}
