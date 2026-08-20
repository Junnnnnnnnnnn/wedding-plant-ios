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

    /// 신규 사용자로 흉내낼지 여부.
    ///
    /// 기본 데모 유저는 이름·예산·결혼일이 모두 채워져 있어서, 설정 화면에 들어가도
    /// `PlanCompletion.isComplete` 가 true 가 되어 곧바로 메인으로 넘어간다(웹 명세대로).
    /// 그래서 설정 플로우를 보려면 비어 있는 사용자를 돌려줘야 한다.
    var newUser: Bool = false

    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        try? await Task.sleep(for: latency)

        let path = request.url.path
        let json: String

        if path.hasSuffix("/plan/auth/kakao/login") {
            json = "{\"result\":true,\"data\":{\"token\":\"\(DemoData.token)\"}}"
        } else if path.contains("total-amount") {
            // `/plan/user/total-amount` 와 `/plan/room/total-amount/{roomId}` 둘 다.
            json = DemoData.totalAmount
        } else if path.contains("/amount/detail") {
            // 개인(`/plan/user/amount/detail`)과 방(`/plan/room/amount/detail/{id}`) 둘 다.
            json = DemoData.amountDetail
        } else if path.contains("/amount/category-chart") {
            json = DemoData.categoryChart
        } else if path.hasSuffix("/plan/user") {
            json = newUser ? DemoData.newUser : DemoData.user
        } else if path.hasSuffix("/plan/schedule/calendar") {
            json = DemoData.calendar(query: request.url.query)
        } else if path.contains("/plan/schedule/") && !path.hasSuffix("/list") {
            // 상세: /plan/schedule/{id}
            json = DemoData.scheduleDetail(id: Int(path.split(separator: "/").last ?? "") ?? 3)
        } else if path.contains("/plan/schedule") && path.hasSuffix("/list") {
            // roomId 가 있으면 경로가 `/plan/schedule/room/{id}/list` 로 바뀐다.
            // 접미사만 보고 판단해야 두 형태를 모두 잡는다.
            // 계획 중 / 완료는 쿼리로 갈라준다.
            let isCompleted = request.url.query?.contains("status=COMPLETED") ?? false
            // 예산 상세는 카테고리로 좁혀서 요청한다. 데모에서도 실제로 걸러줘야
            // 필터가 동작하는지 화면으로 확인할 수 있다.
            let category = request.url.queryValue("categoryName")
            json = DemoData.schedules(completed: isCompleted, categoryName: category)
        } else if path.contains("/plan/category") {
            // `/plan/category/list`, `/user/list`, `/room/{id}/list` 모두 같은 목록을 준다.
            json = DemoData.categories
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

private extension URL {
    /// 쿼리 한 항목을 퍼센트 디코딩해서 꺼낸다.
    func queryValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
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

    /// 설정 플로우를 처음부터 보기 위한 빈 사용자.
    static let newUser = """
    {"result":true,"data":{"id":"demo-user"}}
    """

    static var user: String {
        """
        {"result":true,"data":{
          "id":"demo-user","name":"지수","weddingDate":"\(weddingDate)","budget":5000,
          "roomId":1,"hasSeenMainGuide":true,"hasSeenBudgetGuide":true,"hasSeenChatGuide":true,
          "members":[
            {"planUserId":"demo-user","name":"지수","image":null,"permission":"OWNER"},
            {"planUserId":"u2","name":"현우","image":null,"permission":"WRITE"}
          ],
          "chatRooms":[{"id":10,"name":"본식 준비"},{"id":11,"name":"신혼여행"}]
        }}
        """
    }

    static let totalAmount = """
    {"result":true,"data":{"totalAmount":5000,"usedAmount":2150,"remainingAmount":2850}}
    """

    /// 카테고리별 막대. 계획 없이 쓴 카테고리(비율 100%)도 하나 넣어 둔다.
    static let categoryChart = """
    {"result":true,"data":{"list":[
      {"categoryName":"웨딩홀","totalAmount":1400,"usedAmount":1200},
      {"categoryName":"스튜디오","totalAmount":600,"usedAmount":450},
      {"categoryName":"신혼여행","totalAmount":820,"usedAmount":0},
      {"categoryName":"예물","totalAmount":650,"usedAmount":0},
      {"categoryName":"드레스","totalAmount":500,"usedAmount":0},
      {"categoryName":"메이크업","totalAmount":180,"usedAmount":0},
      {"categoryName":"본식스냅","totalAmount":0,"usedAmount":500}
    ]}}
    """

    static let amountDetail = """
    {"result":true,"data":{
      "initialCapital":5000,"totalPlannedAndUsedAmount":3400,
      "plannedUseAmount":1250,"usedAmount":2150
    }}
    """

    private static func day(_ offset: Int) -> String {
        KstDate.today().adding(days: offset).dateString
    }

    /// 계획 중 탭. 응답은 배열이 아니라 `{ total, list }` 다.
    /// 일부러 지남/D-day/임박/예정 상태가 모두 한 번은 나오도록 날짜를 배치했다.
    static var plannedSchedules: String {
        """
        {"result":true,"data":{"total":4,"list":[
          {"id":3,"categoryName":"드레스","title":"드레스 1차 피팅","amount":500,
           "startDate":"\(day(-2))","status":"NORMAL","location":"서울 강남구 논현동"},
          {"id":4,"categoryName":"메이크업","title":"헤어·메이크업 리허설","amount":180,
           "startDate":"\(day(0))","status":"NORMAL","location":"서울 서초구"},
          {"id":5,"categoryName":"신혼여행","title":"항공권 예약","amount":820,
           "startDate":"\(day(3))","status":"NORMAL","location":null},
          {"id":6,"categoryName":"예물","title":"반지 상담","amount":650,
           "startDate":"\(day(40))","status":"NORMAL","location":"서울 종로구"}
        ]}}
        """
    }

    /// 일정 상세. 장소·메모·추가 카테고리가 모두 있는 항목으로 만들어 카드가 다 보이게 한다.
    static func scheduleDetail(id: Int) -> String {
        """
        {"result":true,"data":{
          "id":\(id),"title":"드레스 1차 피팅","categoryName":"드레스",
          "payType":"CREDIT","amount":500,"startDate":"\(day(-2))","status":"NORMAL",
          "location":"서울 강남구 논현동 웨딩스트리트",
          "locationLat":37.5108,"locationLng":127.0224,
          "memo":"슬리브 길이 조정 요청. 베일은 다음 방문에 함께 확인하기로 했어요.",
          "addCategoryNameList":["헤어","메이크업","부케"]
        }}
        """
    }

    /// 완료 탭
    static var completedSchedules: String {
        """
        {"result":true,"data":{"total":2,"list":[
          {"id":1,"categoryName":"웨딩홀","title":"더채플앳청담 본식 계약","amount":1200,
           "startDate":"\(day(-20))","status":"COMPLETED","location":"서울 강남구 청담동"},
          {"id":2,"categoryName":"스튜디오","title":"본식 스냅 촬영 예약","amount":450,
           "startDate":"\(day(-6))","status":"COMPLETED","location":"서울 성동구"}
        ]}}
        """
    }

    /// 달력. **요청한 달의 날짜만** 돌려준다.
    ///
    /// 앞·현재·다음 달을 각각 요청하므로, 여기서도 달을 구분해 줘야 화면 병합이 제대로
    /// 도는지 확인할 수 있다.
    static func calendar(query: String?) -> String {
        let today = KstDate.today()
        let entries: [(KstDate, String, String)] = [
            (today.adding(days: -20), "더채플앳청담 본식 계약", "COMPLETED"),
            (today.adding(days: -6), "본식 스냅 촬영 예약", "COMPLETED"),
            (today.adding(days: -2), "드레스 1차 피팅", "NORMAL"),
            (today, "헤어·메이크업 리허설", "NORMAL"),
            (today, "청첩장 시안 확인", "NORMAL"),
            (today, "예식 리허설", "NORMAL"),
            (today.adding(days: 3), "항공권 예약", "NORMAL"),
            (today.adding(days: 40), "반지 상담", "NORMAL"),
        ]

        // 요청한 연·월과 같은 날짜만 남긴다.
        let components = (query ?? "")
            .split(separator: "&")
            .reduce(into: [String: String]()) { result, pair in
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 { result[String(parts[0])] = String(parts[1]) }
            }
        let year = components["year"].flatMap(Int.init)
        let month = components["month"].flatMap(Int.init)

        var byDay: [String: [String]] = [:]
        var order: [String] = []
        for (index, entry) in entries.enumerated() {
            let (date, title, status) = entry
            if let year, let month, date.year != year || date.month != month { continue }
            let key = date.dateString
            if byDay[key] == nil { order.append(key) }
            byDay[key, default: []].append(
                "{\"id\":\(index + 1),\"title\":\"\(title)\",\"status\":\"\(status)\"}"
            )
        }

        let days = order.map { key in
            "{\"day\":\"\(key)\",\"list\":[\(byDay[key]!.joined(separator: ","))]}"
        }
        return "{\"result\":true,\"data\":{\"list\":[\(days.joined(separator: ","))]}}"
    }

    /// 카테고리 목록. 제목 추천이 동작하는 것을 보려면 실제 이름이 있어야 한다.
    static let categories = """
    {"result":true,"data":{"total":8,"list":[
      {"id":1,"name":"웨딩홀","type":"SYSTEM"},
      {"id":2,"name":"스튜디오","type":"SYSTEM"},
      {"id":3,"name":"드레스","type":"SYSTEM"},
      {"id":4,"name":"메이크업","type":"SYSTEM"},
      {"id":5,"name":"신혼여행","type":"SYSTEM"},
      {"id":6,"name":"예물","type":"SYSTEM"},
      {"id":7,"name":"본식스냅","type":"SYSTEM"},
      {"id":8,"name":"내가 만든 카테고리","type":"USER"}
    ]}}
    """

    /// 상태·카테고리로 걸러 준다. 응답 모양은 원본과 같은 `{ total, list }`.
    static func schedules(completed: Bool, categoryName: String?) -> String {
        let source = completed ? completedSchedules : plannedSchedules
        guard
            let category = categoryName?.trimmingCharacters(in: .whitespaces), !category.isEmpty,
            let root = try? JSONSerialization.jsonObject(with: Data(source.utf8)) as? [String: Any],
            var data = root["data"] as? [String: Any],
            let list = data["list"] as? [[String: Any]]
        else {
            return source
        }

        let filtered = list.filter { ($0["categoryName"] as? String) == category }
        data["list"] = filtered
        data["total"] = filtered.count
        let output: [String: Any] = ["result": true, "data": data]
        guard let encoded = try? JSONSerialization.data(withJSONObject: output) else { return source }
        return String(decoding: encoded, as: UTF8.self)
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
