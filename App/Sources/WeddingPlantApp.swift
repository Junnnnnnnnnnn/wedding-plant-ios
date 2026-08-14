import SwiftUI

@main
struct WeddingPlantApp: App {
    @StateObject private var env = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .task {
                    if !env.isDemo {
                        await env.refreshAuthState()
                    }
                }
        }
    }
}
