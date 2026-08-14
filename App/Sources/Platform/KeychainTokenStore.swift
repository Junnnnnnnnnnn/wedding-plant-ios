import Foundation
import Security
import WPNetworking

/// JWT 를 Keychain 에 보관한다.
///
/// 저장 위치는 Keychain 한 곳으로 통일한다.
/// `kSecAttrAccessibleAfterFirstUnlock` — 재부팅 후 첫 잠금 해제 이후에는 백그라운드에서도 읽힌다.
actor KeychainTokenStore: TokenStoring {
    private let service: String
    private let account = "plan_auth_token"

    /// 메모리 캐시. 매 요청마다 Keychain 을 때리지 않기 위한 것.
    private var cached: String?
    private var didLoad = false

    init(service: String = "com.zipshowkorea.weddingplant") {
        self.service = service
    }

    func currentToken() async -> String? {
        if !didLoad {
            cached = readFromKeychain()
            didLoad = true
        }
        return cached
    }

    func save(_ token: String) async {
        cached = token
        didLoad = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func clear() async {
        cached = nil
        didLoad = true

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
