import Foundation

/// JWT 보관소.
///
/// 저장 위치는 **Keychain 한 곳**으로 통일한다. 실제 Keychain 구현은 Security 프레임워크가 필요하므로
/// App 타깃(`App/Sources/Platform/KeychainTokenStore.swift`)에 두고, Core는 이 프로토콜만 안다.
public protocol TokenStoring: Sendable {
    func currentToken() async -> String?
    func save(_ token: String) async
    func clear() async
}

/// 테스트·프리뷰용 인메모리 구현.
public actor InMemoryTokenStore: TokenStoring {
    private var token: String?

    public init(token: String? = nil) {
        self.token = token
    }

    public func currentToken() async -> String? {
        token
    }

    public func save(_ token: String) async {
        self.token = token
    }

    public func clear() async {
        token = nil
    }
}
