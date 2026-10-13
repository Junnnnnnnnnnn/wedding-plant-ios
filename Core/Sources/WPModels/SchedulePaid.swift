import Foundation

/// Android와 같은 결제 규칙: 완료 일정은 항상 결제, 예정 일정은 저장된 결제 값.
/// 수정 시에는 원래 isPaidRaw를 보존해야 완료를 취소했을 때 결제 상태가 복원된다.
public protocol SchedulePayable {
    /// 백엔드가 내려준 원값.
    ///
    /// - Important: 화면에서 이걸 직접 읽지 말 것. `nil` 처리가 빠진다.
    ///   판단은 언제나 ``SchedulePayable/isPaid`` 다.
    var isPaidRaw: Bool? { get }

    /// 상태 원문. `"PLANNED"` / `"COMPLETED"`
    var statusRawValue: String? { get }
}

/// 결제와 일정이 어긋난 경우. 화면에 표시를 붙일지 정할 때 쓴다.
///
/// 둘이 같으면(예정+미결제 / 완료+결제) 예전과 같은 모습이라 아무 표시도
/// 붙이지 않는다 — 대부분의 일정이 여기다. **어긋날 때만** 말해 준다.
public enum PaymentMismatch: String, Hashable, Sendable {
    case paidAhead
    case unpaidDone

    /// 웹 `PAYMENT_MISMATCH_LABEL`. 글자까지 같아야 한다.
    public var label: String {
        switch self {
        case .paidAhead: return "결제함"
        case .unpaidDone: return "미결제"
        }
    }
}

extension SchedulePayable {

    /// 돈이 나갔는가. **돈을 세는 곳은 전부 이 기준이다** —
    /// 홈의 예산 막대·이번 달 지출, 예산 상세의 도넛·카테고리 표·예정/사용 탭,
    /// 캘린더의 이번 달 지출/예정, 보드 완료 묶음의 "N만 원 씀".
    public var isPaid: Bool {
        statusRawValue == "COMPLETED" || isPaidRaw == true
    }

    /// 일정이 끝났는가. **개수를 세는 곳은 이 기준이다** —
    /// 캘린더의 "완료 N", 보드의 묶음 가르기, 진행 눈금.
    public var isScheduleCompleted: Bool {
        statusRawValue == "COMPLETED"
    }

    /// 어긋난 경우에만 값이 있다.
    public var paymentMismatch: PaymentMismatch? {
        let done = isScheduleCompleted
        let paid = isPaid
        if !done && paid { return .paidAhead }
        if done && !paid { return .unpaidDone }
        return nil
    }
}
