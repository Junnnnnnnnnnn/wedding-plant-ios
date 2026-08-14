import Foundation
import WPModels

/// 메인·예산 화면에서 쓰는 금액 요약. 단위는 **만원**(백엔드 계약과 동일).
public struct BudgetSummary: Hashable, Sendable {
    public let total: Int
    public let used: Int
    public let remaining: Int

    public init(total: Int, used: Int, remaining: Int) {
        self.total = total
        self.used = used
        self.remaining = remaining
    }

    /// `GET /plan/user/total-amount` 응답에서 만든다.
    ///
    /// 백엔드가 `remainingAmount` 를 빠뜨리면 `total - used` 로 보정한다.
    public init(_ amount: TotalAmount) {
        let total = amount.totalAmount ?? 0
        let used = amount.usedAmount ?? 0
        self.init(
            total: total,
            used: used,
            remaining: amount.remainingAmount ?? (total - used)
        )
    }

    /// 사용 비율 0.0 ~ 1.0. 총액이 0이면 0.
    public var usedRatio: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    /// 예산 초과 여부.
    public var isOverBudget: Bool { remaining < 0 }
}
