import Foundation

public enum DocumentRules {
    public static let maxBytes = 25 * 1024 * 1024
    public static let contentTypes = ["application/pdf", "image/jpeg", "image/png", "image/webp", "image/heic"]
    public static func validSize(_ count: Int) -> Bool { count > 0 && count <= maxBytes }
    public static func formatStorage(_ bytes: Int?) -> String {
        guard let bytes else { return "—" }
        if bytes == 0 { return "0 MB" }
        let gb = 1024.0 * 1024 * 1024, mb = 1024.0 * 1024
        func one(_ value: Double) -> String {
            let text = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
            return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
        }
        if Double(bytes) >= gb { return "\(one(Double(bytes) / gb)) GB" }
        if Double(bytes) >= mb { return "\(one(Double(bytes) / mb)) MB" }
        return "\(max(1, Int((Double(bytes) / 1024).rounded()))) KB"
    }
}
