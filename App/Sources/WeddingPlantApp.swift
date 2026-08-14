import SwiftUI

@main
struct WeddingPlantApp: App {
    @StateObject private var env = AppEnvironment.bootstrap()
    @StateObject private var guest = GuestStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
                .environmentObject(guest)
                .task {
                    if !env.isDemo {
                        await env.refreshAuthState()
                    }
                }
        }
    }
}
