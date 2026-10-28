import Foundation

public enum MoneyInput {
    public static func text(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        return NSDecimalNumber(value: value).stringValue
    }
    /// Preserve an existing fractional amount when editing; never turn 1.5 into 15.
    ///
    /// 앞의 0 은 뗀다(`0500` → `500`, `00` → `0`) — Android `PlanRules.normalizeDigits`(`^0+(?=[0-9])`). 혼자 남은 `0` 과
    /// 소수의 `0.5` 는 둔다. 예전에는 떼지 않아 온보딩 예산 · 플랜 금액 칸에 `0500` 이 그대로 남았다(2026-10-28 iOS QA ONB-03).
    public static func accept(_ input: String, previous: String, maxDigits: Int = 9) -> String {
        let raw = input.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "^0+(?=[0-9])", with: "", options: .regularExpression)
        guard raw.allSatisfy({ ("0"..."9").contains($0) || $0 == "." }) else { return previous }
        let pieces = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2, (pieces.first?.count ?? 0) <= maxDigits,
              pieces.count < 2 || pieces[1].count <= 3 else { return previous }
        return raw.first == "." ? "0" + raw : raw
    }
}
