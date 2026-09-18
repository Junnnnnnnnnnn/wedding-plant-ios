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
        } else if path.contains("/plan/chat/info/") {
            json = DemoData.chatInfo
        } else if path.contains("/plan/chat/") && !path.contains("/name/") && !path.contains("/message/") {
            // 대화 기록: /plan/chat/{chatRoomId}
            json = DemoData.chatHistory
        } else if path.hasSuffix("/plan/room/list") {
            json = DemoData.roomList
        } else if path.hasSuffix("/plan/feed/list") {
            json = DemoData.feed(categoryName: request.url.queryValue("categoryName"))
        } else if path.hasSuffix("/plan/feed/my/status") {
            json = DemoData.feedMyStatus
        } else if path.hasSuffix("/plan/feed/stats") {
            json = DemoData.feedStats(categoryName: request.url.queryValue("categoryName"))
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
        let year = components["year"].flatMap { Int($0) }
        let month = components["month"].flatMap { Int($0) }

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

    static let chatInfo = """
    {"result":true,"data":{"id":10,"name":"본식 준비","memberList":[
      {"planUserId":"demo-user","name":"지수","image":null,"permission":"OWNER"},
      {"planUserId":"u2","name":"현우","image":null,"permission":"WRITE"}
    ]}}
    """

    /// 대화 기록. 응답은 **최신순**이라 화면이 뒤집어 그린다.
    ///
    /// 어제와 오늘에 걸쳐 두어, 날짜 구분선이 실제로 그려지는지 볼 수 있게 했다.
    /// 일정 카드도 한 건 섞는다.
    static var chatHistory: String {
        // 시각은 UTC 다. KST 로 바뀌어 표시되는지 확인하려면 그대로 둬야 한다.
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> String {
            let day = KstDate.today().adding(days: dayOffset)
            return String(
                format: "%04d-%02d-%02dT%02d:%02d:00.000Z",
                day.year, day.month, day.day, hour, minute
            )
        }

        return """
        {"result":true,"data":{"total":6,"list":[
          {"id":106,"planUserId":"demo-user","planUserName":"지수","messageType":"text",
           "text":"좋아요! 그때 봐요 :)","createDate":"\(at(0, 2, 41))","unreadCount":0},
          {"id":105,"planUserId":"u2","planUserName":"현우","messageType":"schedule",
           "schedule":{"id":3,"categoryName":"드레스","title":"드레스 1차 피팅","amount":500,
                       "startDate":"\(KstDate.today().adding(days: 5).dateString)",
                       "status":"NORMAL","location":"서울 강남구 논현동"},
           "createDate":"\(at(0, 2, 38))","unreadCount":0},
          {"id":104,"planUserId":"u2","planUserName":"현우","messageType":"text",
           "text":"드레스 피팅 일정 올려둘게요","createDate":"\(at(0, 2, 35))","unreadCount":0},
          {"id":103,"planUserId":"demo-user","planUserName":"지수","messageType":"text",
           "text":"본식 스냅은 예약 완료했어요","createDate":"\(at(0, 1, 12))","unreadCount":1},
          {"id":102,"planUserId":"u2","planUserName":"현우","messageType":"text",
           "text":"청담 쪽으로 보고 있어요. 주차도 넉넉하대요","createDate":"\(at(-1, 9, 20))","unreadCount":0},
          {"id":101,"planUserId":"demo-user","planUserName":"지수","messageType":"text",
           "text":"웨딩홀 어디로 정할까요?","createDate":"\(at(-1, 9, 15))","unreadCount":0}
        ]}}
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

    // MARK: - 견적 후기

    /// **비공개 금액은 `amount` 키를 아예 뺀다** — `0` 을 넣으면 "0원" 으로 그려진다.
    /// `notHelpfulCount` 도 넣지 않는다. 응답에 없는 것이 계약이다.
    static func feed(categoryName: String?) -> String {
        let all: [(id: Int, category: String, json: String)] = [
            (1, "스튜디오", """
            {"id":1,"categoryName":"스튜디오","title":"라뮈에스튜디오","amount":450,
             "isAmountPublic":true,"region":"서울 강남구",
             "address":"서울 강남구 논현로 842","placeId":"kakao-1",
             "lat":37.5172,"lng":127.0286,"rating":5,
             "body":"원본 800장 다 받았어요. 실장님이 포즈를 잘 잡아 주셔서 어색하지 않았습니다.",
             "authorDDay":131,"authorRole":"BRIDE","helpfulCount":12,
             "myVote":null,"isMine":false,"createDate":"2026-09-15T02:00:00Z"}
            """),
            (2, "예식장", """
            {"id":2,"categoryName":"예식장","title":"더채플앳청담","amount":1240,
             "isAmountPublic":true,"region":"서울 강남구",
             "address":"서울 강남구 선릉로 757","placeId":"kakao-2",
             "lat":37.5237,"lng":127.0468,"rating":4,
             "body":"보증인원이 200명이라 부담이 있었지만 홀이 예뻐서 만족합니다.",
             "authorDDay":-12,"authorRole":"GROOM","helpfulCount":31,
             "myVote":"HELPFUL","isMine":false,"createDate":"2026-09-11T02:00:00Z"}
            """),
            // 금액 비공개 + 장소 없음. 두 분기를 한 카드로 본다.
            (3, "청첩장", """
            {"id":3,"categoryName":"청첩장","title":"바른손 모바일 청첩장",
             "isAmountPublic":false,"rating":4,
             "body":"디자인은 많은데 고르는 데 오래 걸렸어요.",
             "authorDDay":0,"authorRole":"BRIDE","helpfulCount":3,
             "myVote":null,"isMine":true,"createDate":"2026-08-02T02:00:00Z"}
            """),
            (4, "신혼여행", """
            {"id":4,"categoryName":"신혼여행","title":"푸꾸옥 5박 7일","amount":820,
             "isAmountPublic":true,"region":"해외",
             "lat":0,"lng":0,"rating":5,
             "body":"해외라 지도에는 안 뜨지만 가격 대비 최고였습니다.",
             "authorDDay":-40,"authorRole":"GROOM","helpfulCount":8,
             "myVote":null,"isMine":false,"createDate":"2026-07-20T02:00:00Z"}
            """),
        ]
        let picked = categoryName.map { name in all.filter { $0.category == name } } ?? all
        let list = picked.map(\.json).joined(separator: ",")
        return "{\"result\":true,\"data\":{\"total\":\(picked.count),\"list\":[\(list)]}}"
    }

    static let feedMyStatus = """
    {"result":true,"data":{"postCount":1,"receivedHelpfulCount":3,"postableScheduleCount":2}}
    """

    /// 표본이 적은 카테고리는 **서버가 아예 안 내려 준다**(`MIN_STATS_SAMPLE` = 5).
    /// 데모도 같게 흉내 낸다 — 자가 안 뜨는 분기를 화면에서 볼 수 있어야 한다.
    static func feedStats(categoryName: String?) -> String {
        switch categoryName {
        case "스튜디오":
            return """
            {"result":true,"data":{"categoryName":"스튜디오","sampleCount":42,
             "median":520,"p25":380,"p75":700}}
            """
        case "예식장":
            return """
            {"result":true,"data":{"categoryName":"예식장","sampleCount":67,
             "median":1100,"p25":850,"p75":1500}}
            """
        default:
            // 표본이 모자라면 데이터를 주지 않는다.
            return "{\"result\":true}"
        }
    }
}
