import Combine
import Foundation
import WPDomain
import WPModels
import WPNetworking
import WPUtils

@MainActor
final class MainViewModel: ObservableObject {
    @Published var user: PlanUser?
    @Published var budget: BudgetSummary?
    @Published var schedules: [ScheduleItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsSignIn = false

    /// 결혼일까지 남은 일수. 결혼일이 없으면 nil.
    var dDay: Int? {
        guard let raw = user?.weddingDate,
              let date = KstDate(dateString: raw)
        else { return nil }
        return date.daysFromToday()
    }

    var weddingDateText: String? {
        guard let raw = user?.weddingDate,
              let date = KstDate(dateString: raw)
        else { return nil }
        return "\(date.year)년 \(date.month)월 \(date.day)일"
    }

    /// 다가오는 일정만, 날짜 오름차순.
    var upcoming: [ScheduleItem] {
        let today = KstDate.today()
        return schedules
            .filter { item in
                guard let raw = item.startDate, let date = KstDate(dateString: raw) else { return false }
                return date >= today && !(item.status?.isCompleted ?? false)
            }
            .sorted { lhs, rhs in
                (lhs.startDate ?? "") < (rhs.startDate ?? "")
            }
    }

    var completedCount: Int {
        schedules.filter { $0.status?.isCompleted ?? false }.count
    }

    func load(api: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await api.send(Endpoint.user(), decoding: PlanUser.self)
        } catch let error as APIError {
            handle(error)
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // 아래 두 개는 실패해도 화면 전체를 막지 않는다.
        if let amount = try? await api.send(Endpoint.totalAmount(), decoding: TotalAmount.self) {
            budget = BudgetSummary(amount)
        }
        if let list = try? await api.send(Endpoint.scheduleList(), decoding: [ScheduleItem].self) {
            schedules = list
        }
    }

    private func handle(_ error: APIError) {
        if error.requiresReauthentication {
            // 만료·미인증은 조용히 넘기지 않고 명시적으로 재로그인을 요구한다.
            needsSignIn = true
            errorMessage = error.errorDescription
        } else {
            errorMessage = error.errorDescription
        }
    }
}
