import Foundation
import WPModels
import WPUtils

/// 게스트(비로그인) 로컬 데이터를 로그인 계정으로 옮길 때 쓰는 변환 규칙.
///
/// 웹 `KakaoLoginAlert` 의 마이그레이션 블록을 순수 함수로 분리한 것.
public enum GuestMigration {
    /// 게스트가 입력한 예산·이름·결혼일 + 약관 동의를 `POST /plan/setting` 바디로 변환.
    ///
    /// 약관 동의일이 없으면 웹과 동일하게 **KST 오늘 날짜**로 채운다.
    public static func settingRequest(
        weddingDate: KstDate,
        budget: Int?,
        name: String,
        agreement: AgreementData?,
        now: Date = Date()
    ) -> PlanSettingRequest {
        PlanSettingRequest(
            weddingDate: weddingDate.dateString,
            budget: budget ?? 0,
            name: name,
            requiredAgreementDate: agreement?.requiredAgreementDate ?? KstDate.todayString(now: now),
            adAgreementDate: agreement?.adAgreementDate
        )
    }

    /// 로컬 게스트 일정 목록을 등록 요청 목록으로 변환.
    ///
    /// - Parameters:
    ///   - roomId: `GET /plan/user` 에서 받은 roomId. 있으면 각 일정에 함께 보낸다.
    ///   - now: 시작일이 비어 있는 일정에 채울 기본 날짜의 기준 시각.
    public static func scheduleRequests(
        from items: [ScheduleItem],
        roomId: Int? = nil,
        now: Date = Date()
    ) -> [ScheduleWriteRequest] {
        let fallback = KstDate.todayString(now: now)
        return items.map {
            ScheduleWriteRequest(guestItem: $0, fallbackStartDate: fallback, roomId: roomId)
        }
    }
}
