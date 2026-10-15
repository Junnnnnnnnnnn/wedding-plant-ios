import SwiftUI
import UIKit
import KakaoMapsSDK

/// 카카오맵 iOS SDK(`KakaoMapsSDK`) 를 SwiftUI 에서 쓰기 위한 래퍼 — Android `ui/components/KakaoMapView.kt` 와 짝.
///
/// 로그인과 **같은 네이티브 앱 키**(`KAKAO_NATIVE_APP_KEY`)를 쓰고, 카카오 개발자 콘솔에서
/// **[카카오맵] 제품이 활성화**돼 있어야 타일이 내려옵니다(Android 와 같은 앱). 키가 없거나
/// 인증이 실패하면 지도 대신 안내 문구를 냅니다 — 회색 상자만 남기면 고장인지 비었는지 모릅니다.
///
/// - Parameter onMapClick: nil 이 아니면 지도를 눌러 좌표를 고릅니다(플랜 추가 화면).
struct KakaoMapView: View {
    let latitude: Double
    let longitude: Double
    var zoomLevel: Int = 16
    var onMapClick: ((Double, Double) -> Void)? = nil

    @State private var phase: KakaoMapPhase = KakaoMapSDK.ensure() ? .loading : .failed(KakaoMapSDK.missingKeyMessage)

    var body: some View {
        ZStack {
            if case .failed = phase {} else {
                KakaoMapRepresentable(latitude: latitude, longitude: longitude, zoomLevel: zoomLevel,
                                      onMapClick: onMapClick, phase: $phase)
            }
            switch phase {
            case .loading:
                // 준비될 때까지 자리를 지킵니다 — 타일을 받는 동안 빈 면은 고장처럼 보입니다(Android 와 같음)
                ZStack {
                    WPColor.stone100
                    ProgressView().tint(WPColor.primary)
                }.allowsHitTesting(false)
            case .failed(let message):
                ZStack {
                    WPColor.stone100
                    Text(message).font(WPFont.hak(13)).foregroundStyle(WPColor.stone500)
                        .multilineTextAlignment(.center).padding(16)
                }
            case .ready:
                EmptyView()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("지도")
        .accessibilityIdentifier("kakao.map")
    }
}

enum KakaoMapPhase: Equatable {
    case loading, ready, failed(String)
}

@MainActor
enum KakaoMapSDK {
    private static var initialized = false
    static let missingKeyMessage = "지도를 불러오지 못했어요.\n카카오 앱 키가 설정되지 않았어요."
    static let authFailedMessage = "지도를 불러오지 못했어요.\n카카오 콘솔에서 [카카오맵] 활성화를 확인해 주세요."

    private static var appKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // 빌드 설정이 비어 치환되지 않은 값도 키가 없는 것으로 봅니다
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }

    /// SDK 를 한 번만 켭니다. 키가 없으면 false — 지도 대신 안내를 냅니다(크래시 아님).
    static func ensure() -> Bool {
        if initialized { return true }
        guard let appKey else { return false }
        SDKInitializer.InitSDK(appKey: appKey)
        initialized = true
        return true
    }
}

private struct KakaoMapRepresentable: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let zoomLevel: Int
    let onMapClick: ((Double, Double) -> Void)?
    @Binding var phase: KakaoMapPhase

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> KMViewContainer {
        let container = KMViewContainer(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        context.coordinator.attach(container)
        return container
    }

    func updateUIView(_ uiView: KMViewContainer, context: Context) {
        context.coordinator.parent = self
        context.coordinator.move(latitude: latitude, longitude: longitude)
    }

    /// 화면에서 떨어질 때 엔진을 멈추고 비웁니다 — 안 그러면 화면을 오갈 때마다 렌더러가 하나씩 남습니다
    /// (Android `onRelease` 의 `finish()` 와 같은 이유).
    static func dismantleUIView(_ uiView: KMViewContainer, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MapControllerDelegate {
        var parent: KakaoMapRepresentable
        private var controller: KMController?
        private weak var container: KMViewContainer?
        private var tapHandler: DisposableEventHandler?
        private var shown: (Double, Double)?
        private var observers: [NSObjectProtocol] = []
        private static let viewName = "mapview"
        private static let layerID = "pin"
        private static let styleID = "pin"

        init(_ parent: KakaoMapRepresentable) { self.parent = parent }

        private var map: KakaoMap? { controller?.getView(Self.viewName) as? KakaoMap }

        func attach(_ container: KMViewContainer) {
            self.container = container
            let controller = KMController(viewContainer: container)
            controller.delegate = self
            self.controller = controller
            controller.prepareEngine()
            controller.activateEngine()
            // 앱이 뒤로 가면 렌더링을 멈추고, 돌아오면 다시 켭니다(Android ON_PAUSE/ON_RESUME)
            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.controller?.pauseEngine() }
                },
                center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.controller?.activateEngine() }
                },
            ]
        }

        func detach() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            tapHandler?.dispose()
            tapHandler = nil
            controller?.pauseEngine()
            controller?.resetEngine()
            controller = nil
        }

        // MARK: MapControllerDelegate

        func addViews() {
            let position = MapPoint(longitude: parent.longitude, latitude: parent.latitude)
            let info = MapviewInfo(viewName: Self.viewName, viewInfoName: "map", defaultPosition: position, defaultLevel: parent.zoomLevel)
            controller?.addView(info)
        }

        func addViewSucceeded(_ viewName: String, viewInfoName: String) {
            guard let map, let container else { return }
            map.viewRect = container.bounds
            setUpPin(on: map)
            drawPin(latitude: parent.latitude, longitude: parent.longitude)
            if parent.onMapClick != nil {
                tapHandler = map.addMapTappedEventHandler(target: self, handler: Coordinator.mapTapped)
            }
            parent.phase = .ready
        }

        func addViewFailed(_ viewName: String, viewInfoName: String) {
            parent.phase = .failed(KakaoMapSDK.authFailedMessage)
        }

        func authenticationFailed(_ errorCode: Int, desc: String) {
            parent.phase = .failed(KakaoMapSDK.authFailedMessage)
        }

        func containerDidResized(_ size: CGSize) {
            map?.viewRect = CGRect(origin: .zero, size: size)
        }

        // MARK: 핀 · 카메라

        private func mapTapped(_ param: ViewInteractionEventParam) {
            guard let map else { return }
            let coord = map.getPosition(param.point).wgsCoord
            drawPin(latitude: coord.latitude, longitude: coord.longitude)
            parent.onMapClick?(coord.latitude, coord.longitude)
        }

        /// 좌표가 바뀌면 카메라와 핀을 옮깁니다(검색 결과 선택 등)
        func move(latitude: Double, longitude: Double) {
            guard let map, shown.map({ $0 != (latitude, longitude) }) ?? false else { return }
            map.moveCamera(CameraUpdate.make(target: MapPoint(longitude: longitude, latitude: latitude), zoomLevel: parent.zoomLevel, mapView: map))
            drawPin(latitude: latitude, longitude: longitude)
        }

        private func setUpPin(on map: KakaoMap) {
            let manager = map.getLabelManager()
            _ = manager.addLabelLayer(option: LabelLayerOptions(layerID: Self.layerID, competitionType: .none,
                                                                competitionUnit: .symbolFirst, orderType: .rank, zOrder: 0))
            let icon = PoiIconStyle(symbol: Self.pinImage, anchorPoint: CGPoint(x: 0.5, y: 0.92))
            manager.addPoiStyle(PoiStyle(styleID: Self.styleID, styles: [PerLevelPoiStyle(iconStyle: icon, level: 0)]))
        }

        /// 라벨 레이어를 비우고 지정 좌표에 핀 하나만 남깁니다(Android `drawMarker`)
        private func drawPin(latitude: Double, longitude: Double) {
            guard let layer = map?.getLabelManager().getLabelLayer(layerID: Self.layerID) else { return }
            layer.clearAllItems()
            let options = PoiOptions(styleID: Self.styleID)
            options.rank = 0
            layer.addPoi(option: options, at: MapPoint(longitude: longitude, latitude: latitude))?.show()
            shown = (latitude, longitude)
        }

        /// Android `drawable/ic_map_pin.xml` — 브랜드 분홍 핀(36pt, 24 단위 벡터)
        private static let pinImage: UIImage = {
            let size = CGSize(width: 36, height: 36)
            return UIGraphicsImageRenderer(size: size).image { _ in
                let s = size.width / 24
                let pin = UIBezierPath()
                pin.move(to: CGPoint(x: 12 * s, y: 2 * s))
                pin.addCurve(to: CGPoint(x: 5 * s, y: 9 * s), controlPoint1: CGPoint(x: 8.13 * s, y: 2 * s), controlPoint2: CGPoint(x: 5 * s, y: 5.13 * s))
                pin.addCurve(to: CGPoint(x: 12 * s, y: 22 * s), controlPoint1: CGPoint(x: 5 * s, y: 14.25 * s), controlPoint2: CGPoint(x: 12 * s, y: 22 * s))
                pin.addCurve(to: CGPoint(x: 19 * s, y: 9 * s), controlPoint1: CGPoint(x: 12 * s, y: 22 * s), controlPoint2: CGPoint(x: 19 * s, y: 14.25 * s))
                pin.addCurve(to: CGPoint(x: 12 * s, y: 2 * s), controlPoint1: CGPoint(x: 19 * s, y: 5.13 * s), controlPoint2: CGPoint(x: 15.87 * s, y: 2 * s))
                pin.close()
                UIColor(red: 0xEE / 255, green: 0x2B / 255, blue: 0x8C / 255, alpha: 1).setFill()
                pin.fill()
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 9.5 * s, y: 9 * s, width: 5 * s, height: 5 * s)).fill()
            }
        }()
    }
}
