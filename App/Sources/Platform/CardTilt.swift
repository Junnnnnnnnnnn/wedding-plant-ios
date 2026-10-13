import SwiftUI
import CoreMotion

@MainActor final class CardTilt: ObservableObject {
    @Published var x = 0.0
    @Published var y = 0.0
    private let motion = CMMotionManager()
    private var base: CMAttitude?
    private var began = 0.0
    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        base = nil; began = 0; x = 0; y = 0
        motion.deviceMotionUpdateInterval = 1 / 50
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] sample, _ in
            guard let self, let sample else { return }
            if began == 0 { began = sample.timestamp }
            if sample.timestamp - began < 0.3 { base = sample.attitude.copy() as? CMAttitude; return }
            guard let base, let relative = sample.attitude.copy() as? CMAttitude else { return }
            relative.multiply(byInverseOf: base)
            let q = relative.quaternion
            let sign = q.w < 0 ? -1.0 : 1.0
            var ax = 2 * atan2(q.x * sign, q.w * sign) * 180 / .pi
            var ay = 2 * atan2(q.y * sign, q.w * sign) * 180 / .pi
            let orientation = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.interfaceOrientation
            switch orientation {
            case .landscapeLeft: (ax, ay) = (ay, -ax)
            case .landscapeRight: (ax, ay) = (-ay, ax)
            case .portraitUpsideDown: (ax, ay) = (-ax, -ay)
            default: break
            }
            x = min(25, max(-25, -ax)); y = min(25, max(-25, ay))
        }
    }
    func stop() { motion.stopDeviceMotionUpdates(); x = 0; y = 0; base = nil }
    deinit { motion.stopDeviceMotionUpdates() }
}
