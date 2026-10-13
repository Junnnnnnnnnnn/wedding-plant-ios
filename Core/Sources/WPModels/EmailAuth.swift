import Foundation

public struct EmailCheckResult: Decodable, Sendable {
    public let exists: Bool
    public let socialPlatform: String?
}
public struct AuthTokenResult: Decodable, Sendable {
    public let token: String?
    public let jwt: String?
    public var value: String? { [jwt, token].compactMap { $0 }.first { !$0.isEmpty } }
}
