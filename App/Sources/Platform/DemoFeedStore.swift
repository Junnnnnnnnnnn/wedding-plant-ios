import Foundation
import UIKit
import WPNetworking

/// 데모 모드의 견적 후기 — 올리기 · 고치기 · 내리기 · 사진 자리 · 칩이 실제 서버처럼 서로 맞물리게 상태를 든다.
///
/// `-WPFeedParity`: 안드로이드 `FeedParityTest` · iOS 1:1 비교 캡처와 같은 후기(햇살 스튜디오 · 라뮈에스튜디오, 사진
/// 3·2장)를 쓴다. 사진은 안드로이드 테스트의 `picture()` 와 같은 그림을 기기에서 그려 파일 주소로 준다(네트워크 없음).
actor DemoFeedStore {
    static let shared = DemoFeedStore()

    private var posts: [[String: Any]]?
    private var issuedImages = 0
    private var arguments: [String] { ProcessInfo.processInfo.arguments }
    private var parity: Bool { arguments.contains("-WPFeedParity") }

    /// 처리한 요청이면 응답 JSON(`{result,data}`), 아니면 nil — 나머지 피드 경로는 `DemoTransport` 가 그대로 맡는다.
    func respond(path: String, method: HTTPMethod, url: URL, body: Data?) -> (status: Int, json: String)? {
        if path.hasSuffix("/plan/feed/list") {
            let category = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "category" }?.value
            let list = store().filter { category == nil || ($0["categoryName"] as? String) == category }
            return ok(["total": list.count, "list": list])
        }
        if path.hasSuffix("/plan/feed/categories") {
            // 서버와 같이 많이 올라온 순, 같으면 이름 순
            var counts: [String: Int] = [:]
            for post in store() { if let name = post["categoryName"] as? String, !name.isEmpty { counts[name, default: 0] += 1 } }
            let list = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .map { ["categoryName": $0.key, "count": $0.value] as [String: Any] }
            return ok(["total": list.count, "list": list])
        }
        // 후기 신고 · 차단 — 서버처럼 그 글을 목록 · 칩 수에서 뺀다(다른 대상은 DemoTransport 가 맡는다)
        if path.hasSuffix("/plan/moderation/report") || path.hasSuffix("/plan/moderation/block"),
           let edits = body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
           edits["targetType"] as? String == "FEED", let id = edits["targetId"] as? Int {
            _ = store()
            posts?.removeAll { ($0["id"] as? Int) == id }
            return (200, #"{"result":true}"#)
        }
        if path.hasSuffix("/plan/feed/image"), method == .post {
            issuedImages += 1
            return ok(["key": "feed/demo-\(issuedImages).webp", "uploadUrl": "https://demo.invalid/upload"])
        }
        if path.hasSuffix("/plan/feed/postable"), parity {
            return ok(["list": [
                ["scheduleId": 11, "categoryName": "드레스", "title": "드레스 1차 피팅", "amount": 500, "location": "청담 드레스룸",
                 "locationLat": 37.5245, "locationLng": 127.0411, "startDate": "2026-09-16"],
                ["scheduleId": 12, "categoryName": "예물", "title": "반지 상담", "amount": 180, "startDate": "2026-08-28"],
            ]])
        }
        if path.hasSuffix("/plan/feed/my/status"), parity {
            let mine = store().filter { ($0["isMine"] as? Bool) == true }
            let helpful = mine.reduce(0) { $0 + (($1["helpfulCount"] as? Int) ?? 0) }
            return ok(["postCount": mine.count, "receivedHelpfulCount": helpful, "postableScheduleCount": 2])
        }
        if path.hasSuffix("/plan/place/search"), parity {
            return ok(["total": 2, "list": [
                ["placeId": "8123", "placeName": "청담 드레스룸", "addressName": "서울 강남구 청담동 1", "roadAddressName": "서울 강남구 도산대로 501", "lat": 37.5245, "lng": 127.0411],
                ["placeId": "8124", "placeName": "청담 드레스룸 2호점", "addressName": "서울 강남구 청담동 2", "roadAddressName": "서울 강남구 압구정로 60", "lat": 37.5266, "lng": 127.0388],
            ]])
        }
        if path.hasSuffix("/plan/feed"), method == .post {
            return create(body)
        }
        if path.contains("/plan/feed/public/"), let id = Int(path.split(separator: "/").last ?? "") {
            guard let post = store().first(where: { ($0["id"] as? Int) == id }) else { return (404, #"{"message":"NOT_FOUND"}"#) }
            return ok(post)
        }
        let parts = path.split(separator: "/").suffix(3).map(String.init)
        if parts.count == 3, parts[0] == "plan", parts[1] == "feed", let id = Int(parts[2]) {
            if method == .delete {
                guard store().contains(where: { ($0["id"] as? Int) == id }) else { return (404, #"{"message":"NOT_FOUND","data":{"reason":"NOT_FOUND"}}"#) }
                posts?.removeAll { ($0["id"] as? Int) == id }
                return (200, #"{"result":true}"#)
            }
            if method == .patch { return update(id, body) }
        }
        return nil
    }

    // MARK: - 바꾸기

    private func create(_ body: Data?) -> (Int, String) {
        guard let edits = body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) else { return (400, "{}") }
        let keys = edits["images"] as? [String] ?? []
        var post: [String: Any] = [
            "id": 900 + store().count, "categoryName": "드레스", "title": edits["placeName"] as? String ?? "드레스 1차 피팅",
            "amount": 500, "isAmountPublic": edits["isAmountPublic"] as? Bool ?? true, "rating": edits["rating"] as? Int ?? 5,
            "authorRole": edits["authorRole"] as? String ?? "BRIDE", "helpfulCount": 0, "isMine": true,
            "createDate": ISO8601DateFormatter().string(from: Date()), "images": keys.map { _ in Self.pictureURL }, "imageKeys": keys,
        ]
        if let text = edits["body"] as? String { post["body"] = text }
        if (post["isAmountPublic"] as? Bool) == false { post["amount"] = nil }
        posts?.insert(post, at: 0)
        return (200, #"{"result":true}"#)
    }

    private func update(_ id: Int, _ body: Data?) -> (Int, String) {
        guard let index = store().firstIndex(where: { ($0["id"] as? Int) == id }),
              let edits = body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
              var post = posts?[index] else { return (404, #"{"message":"NOT_FOUND"}"#) }
        // `-WPFeedConflict`: 다른 기기에서 사진이 먼저 바뀐 경우 — 처음 한 번은 409 FEED_CHANGED
        if arguments.contains("-WPFeedConflict"), edits["baseImages"] != nil, !(post["conflicted"] as? Bool ?? false) {
            post["conflicted"] = true
            post["imageKeys"] = ["feed/current.webp"]
            post["images"] = [Self.pictureURL]
            posts?[index] = post
            return (409, #"{"message":"rejected","code":409,"data":{"reason":"FEED_CHANGED"}}"#)
        }
        for key in ["rating", "body", "isAmountPublic", "authorRole"] { if let value = edits[key] { post[key] = value } }
        if (post["isAmountPublic"] as? Bool) == false { post["amount"] = nil }
        if let text = post["body"] as? String, text.isEmpty { post["body"] = nil }
        if edits.keys.contains("place") {
            if let place = edits["place"] as? [String: Any] {
                post["title"] = place["placeName"]; post["address"] = place["address"]; post["placeId"] = place["placeId"]
                post["lat"] = place["lat"]; post["lng"] = place["lng"]
            } else {
                for key in ["address", "placeId", "lat", "lng", "region"] { post[key] = nil }
            }
        }
        if let keys = edits["images"] as? [String] {
            let old = Dictionary(uniqueKeysWithValues: zip(post["imageKeys"] as? [String] ?? [], post["images"] as? [String] ?? []))
            post["imageKeys"] = keys
            post["images"] = keys.map { old[$0] ?? Self.pictureURL }
        }
        posts?[index] = post
        return ok(post)
    }

    // MARK: - 데이터

    private func store() -> [[String: Any]] {
        if let posts { return posts }
        let seeded: [[String: Any]]
        if parity {
            let three = (1...3).map { _ in Self.pictureURL }
            seeded = [
                ["id": 720, "categoryName": "스튜디오", "title": "햇살 스튜디오", "amount": 120, "isAmountPublic": true, "rating": 4,
                 "body": "따뜻한 분위기에서 편하게 촬영했어요.", "authorDDay": 98, "authorRole": "BRIDE", "helpfulCount": 2,
                 "isMine": true, "images": three, "imageKeys": ["a", "b", "c"], "createDate": "2026-10-20T02:00:00Z"],
                ["id": 721, "categoryName": "스튜디오", "title": "라뮈에스튜디오", "amount": 450, "isAmountPublic": true, "rating": 5,
                 "body": "원본 800장 다 받았어요. 실장님이 포즈를 잘 잡아 주셔서 어색하지 않았습니다.",
                 "address": "서울 강남구 논현로 842", "region": "서울 강남구", "authorDDay": 131, "authorRole": "GROOM",
                 "helpfulCount": 12, "myVote": "HELPFUL", "isMine": false, "images": Array(three.prefix(2)),
                 "createDate": "2026-10-15T02:00:00Z"],
                ["id": 722, "categoryName": "상견례", "title": "다정한 식탁", "amount": 80, "isAmountPublic": true, "rating": 5,
                 "body": "양가 가족이 편안하게 인사했어요.", "authorRole": "BRIDE", "helpfulCount": 0, "isMine": false,
                 "createDate": "2026-09-30T02:00:00Z"],
            ]
        } else {
            let envelope = (try? JSONSerialization.jsonObject(with: Data(DemoData.feed(categoryName: nil).utf8))) as? [String: Any]
            seeded = ((envelope?["data"] as? [String: Any])?["list"] as? [[String: Any]]) ?? []
        }
        var posts = seeded
        // `-WPFeedOnePhoto`: 안드로이드 `editPrefillSaveLockAndDelete404` 와 같은 내 후기(키만 하나 · 미리보기 주소 없음)
        if arguments.contains("-WPFeedOnePhoto"), let index = posts.firstIndex(where: { ($0["id"] as? Int) == 720 }) {
            posts[index]["images"] = [String]()
            posts[index]["imageKeys"] = ["feed/a.webp"]
        }
        self.posts = posts
        return posts
    }

    private func ok(_ data: Any) -> (Int, String) {
        let object: [String: Any] = ["result": true, "data": data]
        return (200, String(decoding: (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8), as: UTF8.self))
    }

    /// 안드로이드 `FeedParityTest.picture()` 와 같은 그림(600×600 · 베이지 바탕 · 초록 땅 · 흰 원 · 분홍 원)
    static let pictureURL: String = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-feed-picture.png")
        if !FileManager.default.fileExists(atPath: url.path) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600), format: format).image { context in
                let cg = context.cgContext
                cg.setFillColor(UIColor(red: 237 / 255, green: 220 / 255, blue: 208 / 255, alpha: 1).cgColor)
                cg.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
                cg.setFillColor(UIColor(red: 128 / 255, green: 153 / 255, blue: 123 / 255, alpha: 1).cgColor)
                cg.fill(CGRect(x: 0, y: 400, width: 600, height: 200))
                cg.setFillColor(UIColor(red: 250 / 255, green: 246 / 255, blue: 238 / 255, alpha: 1).cgColor)
                cg.fillEllipse(in: CGRect(x: 140, y: 100, width: 320, height: 320))
                cg.setFillColor(UIColor(red: 224 / 255, green: 168 / 255, blue: 170 / 255, alpha: 1).cgColor)
                cg.fillEllipse(in: CGRect(x: 215, y: 175, width: 170, height: 170))
            }
            try? image.pngData()?.write(to: url)
        }
        return url.absoluteString
    }()
}
