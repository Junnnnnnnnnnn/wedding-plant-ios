import CoreLocation
import Foundation

/// 주소만 저장하는 청첩장의 표시용 좌표 — Android `InvitationLocationResolver`(Geocoder) 대응.
///
/// 위치 권한이나 현재 위치는 쓰지 않습니다(`CLGeocoder` 의 주소 → 좌표는 권한이 필요 없음). 편집 중 매 글자마다
/// 묻지 않게 300ms 뒤에, 6초 안에 답이 없으면 지도 없이 둡니다. 같은 주소는 다시 묻지 않습니다(애플은 지오코딩
/// 요청 수를 제한합니다).
@MainActor
final class InvitationLocationResolver: ObservableObject {
    struct Point: Equatable { let latitude: Double; let longitude: Double }

    @Published private(set) var address = ""
    @Published private(set) var loading = false
    @Published private(set) var point: Point?

    private static var cache: [String: Point?] = [:]
    private var task: Task<Void, Never>?

    func load(_ raw: String) {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != address else { return }
        task?.cancel()
        address = query; point = nil
        if query.isEmpty { loading = false; return }
        if let cached = Self.cache[query] { point = cached; loading = false; return }
        loading = true
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let found = await Self.geocode(query)
            guard !Task.isCancelled, let self, self.address == query else { return }
            Self.cache[query] = found
            self.point = found; self.loading = false
        }
    }

    private static func geocode(_ query: String) async -> Point? {
        let geocoder = CLGeocoder()
        return await withTaskGroup(of: Point?.self) { group in
            group.addTask { @MainActor in
                let marks = try? await geocoder.geocodeAddressString(query, in: nil, preferredLocale: Locale(identifier: "ko_KR"))
                guard let c = marks?.first?.location?.coordinate,
                      c.latitude.isFinite, c.longitude.isFinite,
                      (-90...90).contains(c.latitude), (-180...180).contains(c.longitude),
                      c.latitude != 0 || c.longitude != 0 else { return nil }
                return Point(latitude: c.latitude, longitude: c.longitude)
            }
            group.addTask { try? await Task.sleep(for: .seconds(6)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll(); geocoder.cancelGeocode()
            return first
        }
    }
}
