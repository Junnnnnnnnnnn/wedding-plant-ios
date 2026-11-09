import Foundation
public struct InboxItem: Codable, Identifiable, Sendable {
    public let id: Int
    public let type: String
    public let title: String
    public let body: String
    public let roomId: Int
    public let scheduleId: Int?
    public let readAt: String?
    public let createDate: String
}
public struct InboxPage: Codable, Sendable {
    public var items: [InboxItem]
    public let unreadCount: Int
    public let nextCursor: Int?
}
