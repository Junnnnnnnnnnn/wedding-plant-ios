import Foundation

/// 공유 링크에서 공유 코드를 뽑아낸다.
///
/// 웹은 `https://{도메인}/share/{shareCode}` 를 연다. iOS 는 같은 주소를
/// **Universal Link** 로 받고(웹 서버에 `apple-app-site-association` 필요),
/// 개발 중에는 커스텀 스킴(`weddingplant://share/{code}`)도 함께 받는다.
///
/// 링크 처리는 앱이 열리자마자 도는 코드라 조용히 틀리기 쉽다. 그래서 파싱만 떼어 테스트한다.
public enum ShareLink {

    /// 커스텀 스킴. 웹 도메인이 없는 환경(시뮬레이터·개발)에서도 열 수 있게 둔다.
    public static let scheme = "weddingplant"

    /// 공유 링크 경로의 첫 조각.
    public static let pathPrefix = "share"

    /// 공유 링크면 코드를, 아니면 `nil`.
    ///
    /// 받아들이는 모양:
    /// - `https://example.com/share/ABC123`
    /// - `https://example.com/share/ABC123/` (뒤 슬래시)
    /// - `weddingplant://share/ABC123`
    /// - `weddingplant:///share/ABC123`
    public static func shareCode(from url: URL) -> String? {
        var segments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        // `weddingplant://share/CODE` 는 "share" 가 host 로 들어온다.
        if let host = url.host, !host.isEmpty, url.scheme == scheme {
            segments.insert(host, at: 0)
        }

        guard let index = segments.firstIndex(where: { $0.lowercased() == pathPrefix }),
              segments.indices.contains(index + 1)
        else { return nil }

        let code = segments[index + 1]
            .removingPercentEncoding ?? segments[index + 1]
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 초대 하나 — 코드와 **역할**.
    ///
    /// **초대 링크가 역할을 지닌다.** `?as=spouse` 로 들어오면 바로 `SPOUSE`,
    /// 그냥 들어오면 `READ` 다. 역할을 흘리면 배우자로 부르고도 상대가 조언자로
    /// 들어온다.
    ///
    /// 이미 배우자가 있으면 배우자 링크로 와도 조용히 `READ` 로 들어온다 —
    /// **먼저 들어온 사람이 배우자**다. 그 판단은 백엔드가 한다.
    public struct Invite: Hashable, Sendable {
        public var code: String
        public var asSpouse: Bool

        public init(code: String, asSpouse: Bool) {
            self.code = code
            self.asSpouse = asSpouse
        }

        /// 로그인 후 이어서 참여할 때 저장해 두는 모양. 역할을 함께 싣는다.
        public var storageValue: String {
            asSpouse ? "\(code)?as=spouse" : code
        }

        /// 저장해 둔 값에서 되읽는다.
        public init?(storageValue raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let parts = trimmed.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            let code = String(parts[0]).trimmingCharacters(in: .whitespaces)
            guard !code.isEmpty else { return nil }
            let query = parts.count > 1 ? String(parts[1]) : ""
            self.init(code: code, asSpouse: query.lowercased().contains("as=spouse"))
        }
    }

    /// 링크에서 코드와 역할을 함께 읽는다.
    ///
    /// **`?as=spouse` 를 반드시 함께 읽어야 한다** — 코드만 읽으면 배우자 초대가
    /// 조언자 초대로 조용히 바뀐다.
    public static func invite(from url: URL) -> Invite? {
        guard let code = shareCode(from: url) else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name.lowercased() == "as" }?
            .value?
            .lowercased()
        return Invite(code: code, asSpouse: query == "spouse")
    }

    /// 문자열로 받은 링크. 코드만 그대로 넘어와도(`"ABC123"`) 받아준다.
    ///
    /// 로그인 후 이어서 참여할 때 저장해 둔 값이 코드 자체이기 때문이다.
    /// 코드로 **웹 주소**를 만든다. 남에게 보내는 링크라 커스텀 스킴이 아니다 —
    /// 앱이 없는 사람도 열 수 있어야 초대가 끊기지 않는다.
    ///
    /// - Parameter asSpouse: 신랑·신부로 부르는지. **빠지면 배우자로 부르고도
    ///   상대가 `READ` 로 들어온다** — 초대 링크가 역할을 지닌다.
    public static func inviteURL(
        webBaseURL: String,
        code: String,
        asSpouse: Bool
    ) -> String? {
        let trimmedCode = code.trimmingCharacters(in: .whitespaces)
        guard !trimmedCode.isEmpty else { return nil }
        let base = webBaseURL.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty else { return nil }
        let url = "\(base)/\(pathPrefix)/\(trimmedCode)"
        return asSpouse ? url + "?as=spouse" : url
    }

    public static func shareCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil, let code = shareCode(from: url) {
            return code
        }
        // 링크가 아니면 코드 자체로 본다. 경로 구분자가 섞여 있으면 링크로 보고 버린다.
        return trimmed.contains("/") ? nil : trimmed
    }
}
