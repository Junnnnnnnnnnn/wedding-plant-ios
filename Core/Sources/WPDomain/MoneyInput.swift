import Foundation

public enum MoneyInput {
    public static func text(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        return NSDecimalNumber(value: value).stringValue
    }
    /// Preserve an existing fractional amount when editing; never turn 1.5 into 15.
    public static func accept(_ input: String, previous: String, maxDigits: Int = 9) -> String {
        let raw = input.replacingOccurrences(of: ",", with: "")
        guard raw.allSatisfy({ ("0"..."9").contains($0) || $0 == "." }) else { return previous }
        let pieces = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2, (pieces.first?.count ?? 0) <= maxDigits,
              pieces.count < 2 || pieces[1].count <= 3 else { return previous }
        return raw.first == "." ? "0" + raw : raw
    }
}
