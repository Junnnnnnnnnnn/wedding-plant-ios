import Combine
import Foundation
import WPModels
import WPNetworking

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

    let scheduleId: Int

    init(scheduleId: Int) {
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
        errorMessage = nil
        defer { loading = false }

        do {
            // 화면이 로딩 카드를 직접 그리므로 전역 오버레이는 띄우지 않는다.
            detail = try await env.api.send(
                Endpoint.schedule(id: scheduleId),
                decoding: ScheduleDetail.self
            )
        } catch let error as APIError {
            // 401 의 토큰 정리·재로그인 안내는 APIClient 가 공통으로 맡는다.
            // 여기서는 화면을 되돌리기 위한 플래그만 세운다.
            errorMessage = error.errorDescription
            sessionExpired = error.requiresReauthentication
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(env: AppEnvironment, guest: GuestStore) async {
        guard let id = detail?.id, !deleting else { return }

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
