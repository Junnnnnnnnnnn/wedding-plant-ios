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

// MARK: - 준비 패스 결제 (App Store)

extension Endpoint {
    /// 결제할 방을 서버에서 받는다(없으면 만든다, 멱등). **결제 직전에만** 부른다 — 읽기 경로에 쓰면 구경만 한 사람에게도
    /// 방이 생긴다(안드로이드 `OwnRoomResolver.ensure`).
    public static func ensureMyRoom() -> HTTPRequest { HTTPRequest(method: .post, path: "/plan/room/mine") }

    /// App Store 거래(JWS)를 서버가 확인하고 패스를 켠다. 응답은 패스 상태(`PassState`).
    /// 같은 거래(transactionId)를 다시 보내도 기간이 늘지 않는다(멱등) — 복구·복원이 마음 놓고 다시 보낸다.
    public static func verifyApplePurchase(roomId: Int, signedTransaction: String) throws -> HTTPRequest {
        struct Body: Encodable { let roomId: Int; let signedTransaction: String }
        return try .json(.post, "/plan/pass/apple/verify", body: Body(roomId: roomId, signedTransaction: signedTransaction))
    }
}

extension APIError {
    /// 실패 응답의 사유 코드(`data.reason`, 없으면 최상위 `reason`). 백엔드 `ServiceErrorFilter` 가
    /// `{ message, code, traceId, data }` 를 내려 주고 `data` 가 사유를 담는다(안드로이드 `ApiClient.reasonOf`).
    public var serverReason: String? {
        guard let object = serverBody else { return nil }
        if let data = object["data"] as? [String: Any], let reason = data["reason"] as? String, !reason.isEmpty { return reason }
        if let reason = object["reason"] as? String, !reason.isEmpty { return reason }
        return nil
    }

    private var serverBody: [String: Any]? {
        guard case let .http(_, body) = self, let data = body?.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
