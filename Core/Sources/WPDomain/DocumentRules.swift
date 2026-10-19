import Foundation

public enum DocumentRules {
    public static let maxBytes = 25 * 1024 * 1024
    public static let contentTypes = ["application/pdf", "image/jpeg", "image/png", "image/webp", "image/heic"]
    public static func validSize(_ count: Int) -> Bool { count > 0 && count <= maxBytes }

    /// 새 플랜에 **저장 전에** 담아 둘 수 있는 서류 수(Android `DocumentRules.MAX_STAGED`, 2026-10-16 사용자 "플랜 등록할 때
    /// 첨부"). 저장 버튼이 하나씩 올리는 동안 기다려야 해서 넉넉히 두지 않는다 — 더 붙일 것은 수정하기에서 붙인다.
    public static let maxStaged = 10

    /// 담아 둔 것에 새로 고른 것을 더한다 — 이미 담은 것 · 같은 것은 한 번만, `max` 를 넘는 것은 뺀다.
    /// 뺀 개수도 함께 돌려줘 "몇 개까지" 를 말할 수 있게 한다(Android `DocumentRules.stage`).
    public static func stage<T: Equatable>(_ current: [T], picked: [T], max: Int = maxStaged) -> (kept: [T], dropped: Int) {
        var fresh: [T] = []
        for item in picked where !current.contains(item) && !fresh.contains(item) { fresh.append(item) }
        let room = Swift.max(max - current.count, 0)
        return (current + fresh.prefix(room), Swift.max(fresh.count - room, 0))
    }

    /// 담지 못한 것이 있을 때 — 한도는 한 번이 아니라 **전체** 개수다
    public static let stageLimitMessage = "서류는 \(maxStaged)개까지 담을 수 있어요. 나머지는 저장한 뒤 수정하기에서 붙여 주세요."

    /// 저장 뒤 올리다 멈추는 까닭 — 다시 해도 같은 답(패스 없음 · 방 용량 초과 · 방장 · 배우자가 아님)
    public static let stopReasons: Set<String> = ["PASS_REQUIRED", "STORAGE_FULL", "DOCS_OWNER_ONLY"]

    /// 저장 뒤 못 올린 서류의 안내. 멈춘 까닭이 있으면 그 문장이 곧 할 일이다(Android `PendingDocUploader.notice`)
    public static func pendingNotice(failed: Int, stopMessage: String?) -> String {
        stopMessage ?? "서류 \(failed)개를 못 올렸어요. 수정하기에서 다시 붙여 주세요."
    }
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
