import Foundation

/// Android EmailAuthRules와 동일한 입력 규칙. 비밀번호는 정규화하지 않는다.
public enum EmailAuthRules {
    public static let resendCooldown: TimeInterval = 30
    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    public static func validEmail(_ value: String) -> Bool {
        value.utf16.count <= 254 && value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
    public static func sanitizeCode(_ raw: String) -> String {
        String(raw.filter { $0.isASCII && $0 >= "0" && $0 <= "9" }.prefix(6))
    }
    public static func validCode(_ value: String) -> Bool { value.count == 6 && sanitizeCode(value) == value }
    public static func validPassword(_ value: String) -> Bool { (8...72).contains(value.utf16.count) }
    public static func socialLabel(_ value: String?) -> String? {
        switch value { case "kakao": "카카오"; case "google": "Google"; case "apple": "Apple"; default: nil }
    }
}
