import Foundation

/// 일정의 **결제 여부**.
///
/// ── 축이 둘이다 ─────────────────────────────────────────────
/// `status` 는 **일정이 끝났는가**, `isPaid` 는 **돈이 나갔는가**다. 예전에는
/// 축이 하나뿐이라 계약금을 미리 낸 돈이 "아직 안 쓴 예정" 으로 잡혔다 —
/// 통장에서는 이미 빠져나갔는데 예산에 안 보였다. 반대로 끝났는데 아직
/// 정산 안 한 것은 쓴 돈이 아니다.
///
///   예정 + 미결제   아직 아무것도
///   예정 + 결제     미리 낸 계약금
///   완료 + 결제     끝났고 냈다 (예전의 "완료")
///   완료 + 미결제   끝났는데 아직 정산 안 함
///
/// ── `nil` 은 `false` 가 아니다 ───────────────────────────────
/// 이 값이 생기기 전에 만들어진 일정은 값이 없는데, 그때는 **완료가 곧
/// 결제**였다. 그래서 없으면 `status == "COMPLETED"` 로 읽는다. 둘을 같게
/// 다루면 쌓여 있는 완료 일정이 통째로 미결제가 되어 지출이 0 이 된다.
///
/// 웹 `lib/schedulePaid.ts` · 백엔드 `isSchedulePaid()` 와 **같은 규칙**이다 —
/// 한쪽만 고치지 말 것.
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
        if let isPaidRaw { return isPaidRaw }
        return statusRawValue == "COMPLETED"
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
