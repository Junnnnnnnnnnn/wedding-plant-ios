import Foundation

/// Whole replacement. Explicit date/time null clears previously saved values.
public struct InvitationWriteRequest: Encodable, Sendable {
    public var content: InvitationContent
    public var createOnly: Bool
    public init(content: InvitationContent, createOnly: Bool) { self.content = content; self.createOnly = createOnly }
    private enum CodingKeys: String, CodingKey {
        case template, title, bride, groom, weddingDate, weddingTime, venue, message, photos, design, published, baseUpdatedAt, createOnly
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content.template, forKey: .template)
        try c.encode(content.title, forKey: .title)
        try c.encode(content.bride, forKey: .bride)
        try c.encode(content.groom, forKey: .groom)
        try c.encode(content.weddingDate, forKey: .weddingDate)
        try c.encode(content.weddingTime, forKey: .weddingTime)
        try c.encode(content.venue, forKey: .venue)
        try c.encode(content.message, forKey: .message)
        try c.encode(content.photos.map(\.key), forKey: .photos)
        try c.encode(content.design ?? InvitationDesignBody(), forKey: .design)
        try c.encode(content.published, forKey: .published)
        if createOnly { try c.encode(true, forKey: .createOnly) }
        else if !content.updatedAt.isEmpty { try c.encode(content.updatedAt, forKey: .baseUpdatedAt) }
    }
}
