import Foundation
extension Endpoint {
    public static func inbox(before: Int? = nil) -> HTTPRequest {
        HTTPRequest(path: "/plan/notification/inbox", query: before.map { ["before": String($0)] } ?? [:])
    }
    public static func readInbox(_ id: Int) -> HTTPRequest { HTTPRequest(method: .patch, path: "/plan/notification/inbox/\(id)/read") }
    public static func clearUnreadInbox() -> HTTPRequest { HTTPRequest(method: .delete, path: "/plan/notification/inbox/unread") }
}
