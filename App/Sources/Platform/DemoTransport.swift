import Foundation
import WPNetworking
import WPUtils

/// 백엔드 없이 앱을 띄우기 위한 가짜 전송 계층.
///
/// CI(GitHub Actions) 시뮬레이터는 로컬 백엔드(`:3111`)에 접근할 수 없다.
/// 그래서 스크린샷·동영상 촬영과 SwiftUI 프리뷰에서는 이 전송 계층을 주입해
/// 채워진 화면을 보여준다. 실행 인자에 `-WPDemoMode` 가 있으면 활성화된다.
struct DemoTransport: HTTPTransport {
    /// 로딩 상태가 화면에 보이도록 약간의 지연을 준다.
    var latency: Duration = .milliseconds(200)

    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        try? await Task.sleep(for: latency)

        let path = request.url.path
        let json: String

        if path.hasSuffix("/plan/auth/kakao/login") {
            json = "{\"result\":true,\"data\":{\"token\":\"\(DemoData.token)\"}}"
        } else if path.hasSuffix("/plan/user/total-amount") {
            json = DemoData.totalAmount
        } else if path.hasSuffix("/plan/user/amount/detail") {
            json = DemoData.amountDetail
        } else if path.hasSuffix("/plan/user") {
            json = DemoData.user
        } else if path.hasSuffix("/plan/schedule/list") {
            json = DemoData.scheduleList
        } else if path.hasSuffix("/plan/room/list") {
            json = DemoData.roomList
        } else {
            // 아직 데모 데이터를 만들지 않은 엔드포인트는 성공만 돌려준다.
            json = "{\"result\":true}"
        }

        return HTTPResponse(
            status: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(json.utf8)
        )
    }
}

/// 데모 모드에서 쓰는 고정 데이터.
enum DemoData {

    /// 결혼일은 항상 오늘로부터 92일 뒤로 만들어, 언제 캡처해도 D-92 로 보이게 한다.
    static var weddingDate: String {
        KstDate.today().adding(days: 92).dateString
    }

    /// 만료되지 않은 가짜 JWT.
    ///
    /// `APIClient` 가 `exp` 를 검사해 만료 토큰을 차단하므로, 데모용이라도 형식이 맞아야 한다.
    /// 서명은 검증하지 않으므로 아무 값이나 넣는다.
    static let token: String = {
        let exp = Int(Date().addingTimeInterval(60 * 60 * 24 * 365).timeIntervalSince1970)
        let payload = "{\"planUserId\":\"demo-user\",\"sub\":\"demo\",\"exp\":\(exp)}"
        let encoded = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJIUzI1NiJ9.\(encoded).demo-signature"
    }()

    static var user: String {
        """
        {"result":true,"data":{
          "id":"demo-user","name":"지수","weddingDate":"\(weddingDate)","budget":5000,
          "roomId":1,"hasSeenMainGuide":true,"hasSeenBudgetGuide":true,"hasSeenChatGuide":true,
          "chatRooms":[{"id":10,"name":"본식 준비"},{"id":11,"name":"신혼여행"}]
        }}
        """
    }

    static let totalAmount = """
    {"result":true,"data":{"totalAmount":5000,"usedAmount":2150,"remainingAmount":2850}}
    """

    static let amountDetail = """
    {"result":true,"data":{
      "initialCapital":5000,"totalPlannedAndUsedAmount":3400,
      "plannedUseAmount":1250,"usedAmount":2150
    }}
    """

    static var scheduleList: String {
        let today = KstDate.today()
        func day(_ offset: Int) -> String { today.adding(days: offset).dateString }
        return """
        {"result":true,"data":[
          {"id":1,"categoryName":"웨딩홀","title":"더채플앳청담 본식 계약","amount":1200,
           "startDate":"\(day(-20))","status":"COMPLETED","location":"서울 강남구 청담동"},
          {"id":2,"categoryName":"스튜디오","title":"본식 스냅 촬영 예약","amount":450,
           "startDate":"\(day(-6))","status":"COMPLETED","location":"서울 성동구"},
          {"id":3,"categoryName":"드레스","title":"드레스 1차 피팅","amount":500,
           "startDate":"\(day(3))","status":"PLANNED","location":"서울 강남구 논현동"},
          {"id":4,"categoryName":"메이크업","title":"헤어·메이크업 리허설","amount":180,
           "startDate":"\(day(12))","status":"PLANNED","location":"서울 서초구"},
          {"id":5,"categoryName":"신혼여행","title":"항공권 예약","amount":820,
           "startDate":"\(day(25))","status":"PLANNED","location":null},
          {"id":6,"categoryName":"예물","title":"반지 상담","amount":650,
           "startDate":"\(day(40))","status":"PLANNED","location":"서울 종로구"}
        ]}
        """
    }

    static var roomList: String {
        """
        {"result":true,"data":{"total":2,"list":[
          {"roomId":1,"onwerName":"지수","weddingDate":"\(weddingDate)","budget":5000,
           "remainingBudget":2850,"planCount":6,
           "chatRooms":[{"id":10,"name":"본식 준비"}],
           "members":[
             {"planUserId":"demo-user","name":"지수","image":null,"permission":"OWNER"},
             {"planUserId":"u2","name":"현우","image":null,"permission":"WRITE"}
           ]},
          {"roomId":2,"onwerName":"현우","weddingDate":"\(weddingDate)","budget":3000,
           "remainingBudget":1900,"planCount":3,
           "chatRooms":[{"id":11,"name":"신혼여행"}],
           "members":[
             {"planUserId":"u2","name":"현우","image":null,"permission":"OWNER"},
             {"planUserId":"demo-user","name":"지수","image":null,"permission":"READ"}
           ]}
        ]}}
        """
    }
}
