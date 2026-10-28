import Foundation

/// 홈의 `새 축하 N` 기준 — 청첩장 칸에서 마지막으로 본 하객 수. Android `HomeInvitationStore.seen(slug)` · `markSeen(slug, total)`.
///
/// **청첩장(주소)마다 · 계정마다** 따로 든다(Android 1e62d83). 계정 하나에 한 수만 들면 다른 청첩장(배우자 플랜으로 옮김 ·
/// 새로 만듦)으로 바뀌었을 때 옛 청첩장의 수와 빼서 새 축하를 지어내거나 숨겼다. 예전 값은 어느 청첩장 것인지 몰라 옮기지 않는다.
enum InvitationSeenStore {
    private static let prefix = "invitation.seen-book."
    private static var defaults: UserDefaults { .standard }

    private static func key(account: String, slug: String) -> String? {
        let slug = slug.trimmingCharacters(in: .whitespaces)
        guard !account.isEmpty, !slug.isEmpty else { return nil }
        return "\(prefix)\(account).\(slug)"
    }

    static func seen(account: String, slug: String) -> Int? {
        guard let key = key(account: account, slug: slug), defaults.object(forKey: key) != nil else { return nil }
        return defaults.integer(forKey: key)
    }

    static func markSeen(account: String, slug: String, total: Int) {
        guard let key = key(account: account, slug: slug) else { return }
        defaults.set(max(0, total), forKey: key)
    }

    /// 로그아웃 — 모든 계정 것을 지운다
    static func clear() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) { defaults.removeObject(forKey: key) }
    }
}
