import Foundation
import WPNetworking

/// 실제 네트워크 전송. Core 의 `HTTPTransport` 를 URLSession 으로 구현한다.
///
/// 이 파일이 App 타깃에 있는 이유: Windows 의 swift-corelibs-foundation 은 URLSession 을
/// 별도 모듈로 분리해 두었고 동작도 불완전해서, Core 에 두면 Windows 빌드가 깨진다.
struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: PreparedRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.transport("HTTP 응답이 아닙니다")
            }
            var headers: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                if let key = key as? String, let value = value as? String {
                    headers[key] = value
                }
            }
            return HTTPResponse(status: http.statusCode, headers: headers, body: data)
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timedOut
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }
}
