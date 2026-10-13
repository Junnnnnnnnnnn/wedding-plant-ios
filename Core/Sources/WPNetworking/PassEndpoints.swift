import Foundation
import WPModels

extension Endpoint {
    public static func activities(roomId: Int) -> HTTPRequest { HTTPRequest(path: "/plan/activity/list", query: ["roomId": String(roomId), "page": "1", "count": "30"]) }
    public static func pass(roomId: Int) -> HTTPRequest { HTTPRequest(path: "/plan/pass/room/\(roomId)") }
    public static func reminderSetting() -> HTTPRequest { HTTPRequest(path: "/plan/pass/reminder-setting") }
    public static func saveReminder(leadDays: [Int], hour: Int, email: Bool) throws -> HTTPRequest {
        struct Body: Encodable { let leadDays: [Int]; let hour: Int; let email: Bool }
        return try .json(.put, "/plan/pass/reminder-setting", body: Body(leadDays: leadDays, hour: hour, email: email))
    }
    public static func scheduleFiles(_ id: Int) -> HTTPRequest { HTTPRequest(path: "/plan/pass/file/schedule/\(id)") }
    public static func fileUpload(scheduleId: Int, fileName: String, contentType: String, sizeBytes: Int) throws -> HTTPRequest {
        struct Body: Encodable { let scheduleId: Int; let fileName: String; let contentType: String; let sizeBytes: Int }
        return try .json(.post, "/plan/pass/file/upload", body: Body(scheduleId: scheduleId, fileName: fileName, contentType: contentType, sizeBytes: sizeBytes))
    }
    public static func completeFile(_ id: Int) -> HTTPRequest { HTTPRequest(method: .post, path: "/plan/pass/file/\(id)/complete") }
    public static func fileURL(_ id: Int, inline: Bool = false) -> HTTPRequest {
        HTTPRequest(path: "/plan/pass/file/\(id)/url", query: inline ? ["inline": "1"] : [:])
    }
    public static func deleteFile(_ id: Int) -> HTTPRequest { HTTPRequest(method: .delete, path: "/plan/pass/file/\(id)") }
    public static func allFiles(roomId: Int) -> HTTPRequest { HTTPRequest(path: "/plan/pass/file/room/\(roomId)/download-all") }
    public static func exportExcel(roomId: Int) -> HTTPRequest { HTTPRequest(path: "/plan/pass/file/room/\(roomId)/export") }
    public static func myInvitation() -> HTTPRequest { HTTPRequest(path: "/plan/my-invitation") }
    public static func saveInvitation(_ body: InvitationWriteRequest) throws -> HTTPRequest { try .json(.put, "/plan/my-invitation", body: body) }
    public static func invitationPhoto(contentType: String, sizeBytes: Int) throws -> HTTPRequest {
        struct Body: Encodable { let contentType: String; let sizeBytes: Int }
        return try .json(.post, "/plan/my-invitation/photo", body: Body(contentType: contentType, sizeBytes: sizeBytes))
    }
    public static func invitationGuestbook(slug: String) -> HTTPRequest {
        HTTPRequest(path: "/plan/invitation/\(escape(slug))/guestbook", requiresAuth: false)
    }
}
