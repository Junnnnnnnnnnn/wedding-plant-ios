import Foundation
import WPModels

/// 푸시를 받았을 때 무엇을 보여줄지.
public enum PushDisplay: Hashable, Sendable {
    /// 시스템 알림 배너.
    case system
    /// 배너 없이 인앱 토스트만. 앱을 보고 있는데 배너까지 뜨면 시끄럽다.
    case inAppOnly
    /// 아무것도 안 띄운다. 지금 그 대화를 보고 있는 경우.
    case suppress
}

/// 알림을 눌렀을 때 갈 곳.
public enum PushDestination: Hashable, Sendable {
    case chatRoom(id: Int)
    /// 어디로 갈지 알 수 없음 — 앱만 연다.
    case none
}

/// 푸시 처리 규칙. 화면 없이 검증할 수 있도록 판단만 떼어 놓는다.
///
/// 규칙은 안드로이드 `IOS_PORTING_NOTES` §3-1 과 같다:
/// - 앱이 켜져 있을 때는 **시스템 알림 대신 인앱 토스트만**
/// - **지금 보고 있는 채팅방**의 메시지는 배너도 토스트도 띄우지 않는다
/// - SSE(인앱)와 푸시가 둘 다 알림을 띄우면 같은 메시지로 두 번 뜬다
public enum PushRouting {

    /// - Parameters:
    ///   - appActive: 앱이 화면에 떠 있는지(`scenePhase == .active`).
    ///   - currentChatRoomId: 지금 열려 있는 채팅방. 없으면 nil.
    ///
    /// - Note: 앱이 백그라운드일 때는 애초에 앱이 개입할 수 없고 시스템이 배너를 띄운다.
    ///   그래서 ``PushDisplay/suppress`` 는 앱이 켜져 있을 때만 의미가 있다.
    public static func display(
        for payload: PushPayload,
        appActive: Bool,
        currentChatRoomId: Int?
    ) -> PushDisplay {
        guard appActive else { return .system }

        if let roomId = payload.chatRoomId, roomId == currentChatRoomId {
            return .suppress
        }
        return .inAppOnly
    }

    /// 알림을 눌렀을 때 갈 곳.
    public static func destination(for payload: PushPayload) -> PushDestination {
        guard let roomId = payload.chatRoomId else { return .none }
        return .chatRoom(id: roomId)
    }

    /// 인앱 토스트 문구. 보낸 사람이 비어 있으면 본문만 보여준다.
    public static func toastText(for payload: PushPayload) -> String {
        let sender = payload.senderName.trimmingCharacters(in: .whitespaces)
        let body = payload.body.trimmingCharacters(in: .whitespaces)
        if sender.isEmpty { return body }
        if body.isEmpty { return sender }
        return "\(sender): \(body)"
    }

    /// APNs 기기 토큰(Data)을 백엔드가 받는 16진 문자열로.
    ///
    /// FCM 을 쓰면 FCM 등록 토큰을 보내지만, 백엔드가 APNs 로 직접 쏘는 경우를 위해 남겨 둔다.
    public static func hexToken(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
