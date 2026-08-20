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
    /// - Important: 바디 키는 반드시 **`kakaoToken`** 이다 (웹 `KakaoLoginAlert.tsx` 와 동일).
    ///   `accessToken` 등 다른 이름으로 보내면 백엔드가 **HTTP 400** 으로 거절한다.
    ///   응답의 `data.token` 이 앱 JWT 다.
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

    /// - Warning: **프로필 수정에는 쓰지 말 것.** `createSetting(_:)`(POST `/plan/setting`)을 쓴다.
    ///
    ///   `PATCH /plan/user` 는 `requiredAgreementDate`·`adAgreementDate` 를 **둘 다 문자열 필수**로
    ///   검증하는데 `GET /plan/user` 응답에는 그 두 필드가 없다. null 을 보내면 **항상 400** 이고,
    ///   `adAgreementDate` 를 채우면 마케팅 미동의자에게 수신 동의가 기록된다.
    ///
    ///   `/plan/setting` 은 같은 값을 갱신하면서 `adAgreementDate` 생략을 허용한다.
    ///   `requiredAgreementDate` 는 여전히 필수라 값이 없으면 **KST 오늘**을 보낸다.
    @available(*, deprecated, message: "프로필 수정은 createSetting(_:) 을 쓰세요. PATCH /plan/user 는 항상 400 입니다.")
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

    /// 카테고리 목록. **비로그인 게스트용이라 인증 헤더를 붙이지 않는다.**
    ///
    /// 로그인 상태라면 `userCategoryList()`, 방이 있으면 `roomCategoryList(roomId:)` 를 쓴다.
    /// 안드로이드는 게스트에게도 `user/list` 를 불러서 카테고리가 하나도 안 보였고,
    /// 카테고리가 필수라 **게스트가 플랜을 아예 만들 수 없었다.**
    public static func categoryList() -> HTTPRequest {
        HTTPRequest(path: "/plan/category/list", requiresAuth: false)
    }

    public static func userCategoryList() -> HTTPRequest {
        HTTPRequest(path: "/plan/category/user/list")
    }

    public static func roomCategoryList(roomId: Int) -> HTTPRequest {
        HTTPRequest(path: "/plan/category/room/\(roomId)/list")
    }

    /// 상황에 맞는 카테고리 목록 경로를 고른다.
    ///
    /// | 상황 | 경로 |
    /// | --- | --- |
    /// | 방이 있음 | `/plan/category/room/{roomId}/list` |
    /// | 로그인함 | `/plan/category/user/list` |
    /// | **비로그인** | `/plan/category/list` (인증 헤더 없이) |
    ///
    /// 안드로이드는 게스트에게도 `user/list` 를 불러서 카테고리가 하나도 안 보였고,
    /// 카테고리가 필수라 **게스트는 플랜을 아예 만들 수 없었다.**
    public static func categories(roomId: Int?, loggedIn: Bool) -> HTTPRequest {
        if let roomId { return roomCategoryList(roomId: roomId) }
        return loggedIn ? userCategoryList() : categoryList()
    }

    // MARK: - 장소 검색

    /// `GET /plan/place/search` — 장소 키워드 검색 (백엔드 프록시).
    ///
    /// - Important: 이 엔드포인트는 **아직 백엔드에 없다.** 호출하면 404 가 온다.
    ///   화면은 안내 문구로 처리하고, 서버에 생기면 그대로 붙게 만들 것.
    ///   (카카오 REST 키를 앱 번들에 넣지 않으려고 프록시로 가는 설계다)
    public static func searchPlaces(query: String, size: Int = 10) -> HTTPRequest {
        HTTPRequest(
            path: "/plan/place/search",
            query: ["query": query.trimmingCharacters(in: .whitespaces), "size": "\(size)"]
        )
    }

    // MARK: - 푸시 기기 토큰

    /// 백엔드가 허용하는 플랫폼 값. 다른 값을 보내면 400.
    public enum DevicePlatform: String, Sendable {
        case ios = "IOS"
        case android = "ANDROID"
    }

    /// APNs(FCM 경유) 기기 토큰 등록.
    ///
    /// 토큰은 재설치·데이터 삭제·장기 미사용으로 바뀐다. 갱신 콜백마다 재등록하고,
    /// **설치 후 첫 로그인에는 갱신 콜백이 오지 않으므로 로그인 직후에도 한 번 등록**한다.
    public static func registerDeviceToken(_ token: String) throws -> HTTPRequest {
        try .json(
            .post,
            "/plan/user/device-token",
            body: ["token": token, "platform": DevicePlatform.ios.rawValue]
        )
    }

    /// 기기 토큰 해제. **로그아웃 시 JWT 를 지우기 전에** 호출해야 한다.
    ///
    /// 해제하지 않으면 로그아웃해도 그 기기로 알림이 계속 간다 —
    /// 기기를 넘기거나 공용 기기를 쓰면 남의 채팅 내용이 그대로 뜬다.
    public static func unregisterDeviceToken(_ token: String) throws -> HTTPRequest {
        try .json(.delete, "/plan/user/device-token", body: ["token": token])
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
