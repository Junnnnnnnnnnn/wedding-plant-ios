import Foundation
import WPNetworking

enum SignedStorage {
    /// Presigned storage requests must never inherit the application's Authorization header.
    static func upload(url: String, contentType: String, bytes: Data) async throws {
        guard let url = URL(string: url), url.scheme == "https" else { throw APIError.invalidURL("storage") }
        var request = URLRequest(url: url); request.httpMethod = "PUT"; request.httpBody = bytes
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(bytes.count), forHTTPHeaderField: "Content-Length")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw APIError.backend(message: "사진을 끝까지 올리지 못했어요. 다시 시도해 주세요.") }
    }
}
