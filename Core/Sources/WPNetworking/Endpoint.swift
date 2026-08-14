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
    ///
    /// - Note: 바디 키는 `accessToken` 이다. 웹은 서버 라우트를 거치며 `kakaoToken` 을 쓰지만,
    ///   네이티브는 SDK 가 준 access token 을 그대로 보내며 안드로이드 구현과 동일하게 맞춘다.
    public static func kakaoLogin(accessToken: String) throws -> HTTPRequest {
        try .json(
            .post,
            "/plan/auth/kakao/login",
            body: ["accessToken": accessToken],
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
        HTTPRequest(method: .post, path: "/plan/user/has-seen-main-guide")
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

    /// 일정 목록 조회 상태 필터. 계획 중 / 완료를 **따로** 받아온다.
    public enum ScheduleListStatus: String, Sendable {
        case normal = "NORMAL"
        case completed = "COMPLETED"
    }

    /// 웹은 `count=10000` 으로 사실상 전체를 한 번에 받아온다. 동일하게 맞춘다.
    public static let scheduleFetchCount = 10000

    /// `GET /plan/schedule/list` 또는 `GET /plan/schedule/room/{roomId}/list`
    ///
    /// 응답은 배열이 아니라 `{ total, list }`(`SchedulePage`) 다.
    public static func scheduleList(
        status: ScheduleListStatus,
        roomId: String? = nil,
        sortColumn: String = "startDate",
        descending: Bool = true,
        count: Int = scheduleFetchCount
    ) -> HTTPRequest {
        let path: String
        if let roomId, !roomId.trimmingCharacters(in: .whitespaces).isEmpty {
            path = "/plan/schedule/room/\(escape(roomId.trimmingCharacters(in: .whitespaces)))/list"
        } else {
            path = "/plan/schedule/list"
        }
        return HTTPRequest(
            path: path,
            query: [
                "page": "1",
                "count": "\(count)",
                "sort": descending ? "DESC" : "ASC",
                "sortColumn": sortColumn,
                "status": status.rawValue,
            ]
        )
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

    /// 체크박스 토글. 계획 중 <-> 완료.
    public static func updateScheduleStatus(id: Int, status: ScheduleListStatus) throws -> HTTPRequest {
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
