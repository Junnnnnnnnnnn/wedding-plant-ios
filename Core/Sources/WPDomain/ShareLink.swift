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

    /// 문자열로 받은 링크. 코드만 그대로 넘어와도(`"ABC123"`) 받아준다.
    ///
    /// 로그인 후 이어서 참여할 때 저장해 둔 값이 코드 자체이기 때문이다.
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
