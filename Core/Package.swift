// swift-tools-version: 6.0
import PackageDescription

// WeddingPlantCore
//
// UI가 아닌 모든 코드를 담는 패키지.
// SwiftUI/UIKit에 의존하지 않으므로 Windows에서도 `swift build` / `swift test` 가 동작한다.
// 플랫폼 의존 구현(URLSession 전송, Keychain, Kakao SDK)은 App/Sources/Platform 에 둔다.
let package = Package(
    name: "WeddingPlantCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WPModels", targets: ["WPModels"]),
        .library(name: "WPUtils", targets: ["WPUtils"]),
        .library(name: "WPNetworking", targets: ["WPNetworking"]),
        .library(name: "WPDomain", targets: ["WPDomain"]),
    ],
    targets: [
        .target(name: "WPModels"),
        .target(name: "WPUtils"),
        .target(
            name: "WPNetworking",
            dependencies: ["WPModels", "WPUtils"]
        ),
        .target(
            name: "WPDomain",
            dependencies: ["WPModels", "WPUtils", "WPNetworking"]
        ),

        // 테스트 타깃은 import 하는 모듈을 모두 명시한다.
        // (전이 의존에 기대면 툴체인 버전에 따라 import 가 깨질 수 있다.)
        .testTarget(name: "WPModelsTests", dependencies: ["WPModels"]),
        .testTarget(name: "WPUtilsTests", dependencies: ["WPUtils"]),
        .testTarget(name: "WPNetworkingTests", dependencies: ["WPNetworking", "WPModels"]),
        .testTarget(name: "WPDomainTests", dependencies: ["WPDomain", "WPModels", "WPUtils", "WPNetworking"]),
    ]
)
