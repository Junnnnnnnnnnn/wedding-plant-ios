import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking
import WPUtils

/// 웹 `app/calendar/page.tsx` 의 데이터 로딩.
///
/// 격자가 42칸이라 앞뒤 달 날짜도 같이 보인다. 그래서 **앞·현재·다음 달을 한꺼번에 받아**
/// 하루 단위로 합친다 (``CalendarGrid/monthsToFetch(cursor:)`` 주석 참고).
@MainActor
final class CalendarViewModel: ObservableObject {

    /// 화면에 보이는 달의 1일.
    @Published private(set) var cursor: KstDate = KstDate.today().firstOfMonth
    /// "YYYY-MM-DD" → 그 날의 플랜들
    @Published private(set) var byDay: [String: [CalendarPlanItem]] = [:]
    @Published private(set) var loading = true

    /// 읽기 권한이면 추가 버튼을 감춘다. 메인에서 이미 알고 있는 값을 받아 온다.
    let readOnly: Bool

    private let roomId: String?

    /// 늦게 도착한 이전 달 응답이 최신 화면을 덮어쓰지 않도록 세는 순번.
    private var fetchSequence = 0

    init(roomId: String? = nil, readOnly: Bool = false) {
        self.roomId = roomId
        self.readOnly = readOnly
    }

    var year: Int { cursor.year }
    var month: Int { cursor.month }
    var title: String { "\(cursor.year)년 \(cursor.month)월" }

    var grid: [KstDate] { CalendarGrid.build(cursor: cursor) }

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

        let targets = CalendarGrid.monthsToFetch(cursor: cursor)
        let pages = await withTaskGroup(of: CalendarPage?.self) { group in
            for target in targets {
                group.addTask { [roomId, api = env.api] in
                    try? await api.send(
                        Endpoint.calendar(year: target.year, month: target.month, roomId: roomId),
                        decoding: CalendarPage.self
                    )
                }
            }
            var collected: [CalendarPage] = []
            for await page in group {
                if let page { collected.append(page) }
            }
            return collected
        }

        // 더 최신 요청이 시작됐으면 이 응답은 버린다.
        guard sequence == fetchSequence else { return }

        var merged: [String: [CalendarPlanItem]] = [:]
        for page in pages {
            for day in page.list where !day.day.isEmpty {
                merged[day.day] = day.list
            }
        }
        byDay = merged
        loading = false
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
                    status: item.status
                )
            )
        }
        byDay = merged
        loading = false
    }
}
