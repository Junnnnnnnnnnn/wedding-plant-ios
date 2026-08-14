import Foundation
import WPModels

/// 백엔드 엔드포인트 카탈로그.
///
/// 웹 앱에서 실제로 호출하는 `/plan/...` 경로를 한곳에 모았다.
/// 화면 코드가 경로 문자열을 직접 만들지 않게 해서 오타·중복을 막는다.
public enum Endpoint {
    /// 동적 경로 세그먼트 인코딩. (shareCode 등 사용자 입력이 섞이는 경우 필수)
    public static func escape(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? segment
    }

    // MARK: - 인증

    /// 카카오 access token 을 앱 JWT 로 교환. 인증 불필요.
    public static func kakaoLogin(kakaoToken: String) throws -> HTTPRequest {
        try .json(
            .post,
            "/plan/auth/kakao/login",
            body: ["kakaoToken": kakaoToken],
            requiresAuth: false
        )
    }

    // MARK: - 사용자

    public static func user() -> HTTPRequest {
        HTTPRequest(path: "/plan/user")
    }

    public static func updateUser(_ body: PlanSettingRequest) throws -> HTTPRequest {
        try .json(.patch, "/plan/user", body: body)
    }

    public static func totalAmount() -> HTTPRequest {
        HTTPRequest(path: "/plan/user/total-amount")
    }

    public static func amountDetail() -> HTTPRequest {
        HTTPRequest(path: "/plan/user/amount/detail")
    }

    public static func amountCategoryChart() -> HTTPRequest {
        HTTPRequest(path: "/plan/user/amount/category-chart")
    }

    public static func markMainGuideSeen() -> HTTPRequest {
        HTTPRequest(method: .patch, path: "/plan/user/has-seen-main-guide")
    }

    public static func markBudgetGuideSeen() -> HTTPRequest {
        HTTPRequest(method: .patch, path: "/plan/user/has-seen-budget-guide")
    }

    public static func markChatGuideSeen() -> HTTPRequest {
        HTTPRequest(method: .patch, path: "/plan/user/has-seen-chat-guide")
    }

    // MARK: - 설정 (예산·이름·결혼일)

    public static func createSetting(_ body: PlanSettingRequest) throws -> HTTPRequest {
        try .json(.post, "/plan/setting", body: body)
    }

    public static func updateSetting(_ body: PlanSettingRequest) throws -> HTTPRequest {
        try .json(.patch, "/plan/setting", body: body)
    }

    // MARK: - 일정

    public static func scheduleList() -> HTTPRequest {
        HTTPRequest(path: "/plan/schedule/list")
    }

    public static func schedule(id: Int) -> HTTPRequest {
        HTTPRequest(path: "/plan/schedule/\(id)")
    }

    public static func createSchedule(_ body: ScheduleWriteRequest) throws -> HTTPRequest {
        try .json(.post, "/plan/schedule", body: body)
    }

    public static func updateSchedule(id: Int, _ body: ScheduleWriteRequest) throws -> HTTPRequest {
        try .json(.patch, "/plan/schedule/\(id)", body: body)
    }

    public static func deleteSchedule(id: Int) -> HTTPRequest {
        HTTPRequest(method: .delete, path: "/plan/schedule/\(id)")
    }

    public static func updateScheduleStatus(id: Int, status: ScheduleStatus) throws -> HTTPRequest {
        try .json(.patch, "/plan/schedule/status/\(id)", body: ["status": status.rawValue])
    }

    // MARK: - 방 (공유 플랜)

    public static func roomList() -> HTTPRequest {
        HTTPRequest(path: "/plan/room/list")
    }

    public static func room(shareCode: String) -> HTTPRequest {
        HTTPRequest(path: "/plan/room/\(escape(shareCode))")
    }

    /// 공유 링크로 방 참여.
    public static func joinRoom(shareCode: String) -> HTTPRequest {
        HTTPRequest(method: .post, path: "/plan/room/\(escape(shareCode))")
    }

    public static func createRoom(name: String) throws -> HTTPRequest {
        try .json(.post, "/plan/room", body: ["name": name])
    }

    public static func roomTotalAmount(roomId: String) -> HTTPRequest {
        HTTPRequest(path: "/plan/room/total-amount/\(escape(roomId))")
    }

    public static func createChatRoom(roomId: Int, name: String) throws -> HTTPRequest {
        try .json(.post, "/plan/room/\(roomId)/chat", body: ["name": name])
    }

    // MARK: - 채팅

    public static func chatName(chatRoomId: Int) -> HTTPRequest {
        HTTPRequest(path: "/plan/chat/name/\(chatRoomId)")
    }

    public static func chatInfo(chatRoomId: Int) -> HTTPRequest {
        HTTPRequest(path: "/plan/chat/info/\(chatRoomId)")
    }

    public static func unreadCount(roomId: Int) -> HTTPRequest {
        HTTPRequest(path: "/plan/chat/message/count/\(roomId)")
    }

    // MARK: - 카테고리

    public static func categoryList() -> HTTPRequest {
        HTTPRequest(path: "/plan/category/list")
    }

    public static func userCategoryList() -> HTTPRequest {
        HTTPRequest(path: "/plan/category/user/list")
    }

    public static func roomCategoryList(roomId: Int) -> HTTPRequest {
        HTTPRequest(path: "/plan/category/room/\(roomId)/list")
    }

    // MARK: - 알림 (SSE)

    /// 채팅 알림 SSE 경로.
    ///
    /// - Important: 이 경로는 `APIClient` 로 호출하지 않는다. 스트리밍이므로 App 레이어의
    ///   SSE 클라이언트가 사용한다. 또한 iOS는 백그라운드에서 스트림을 유지하지 못하므로
    ///   **실사용 알림은 APNs 푸시가 별도로 필요**하다.
    public static func notificationStreamPath(roomId: Int) -> String {
        "/plan/notification/chat/\(roomId)"
    }
}
