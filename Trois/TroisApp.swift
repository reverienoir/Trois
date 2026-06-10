import SwiftUI
import UserNotifications

@main
struct TroisApp: App {
    @StateObject private var usage = UsageManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(usage)
                .fullScreenCover(isPresented: .init(
                    get: { !hasSeenOnboarding },
                    set: { if !$0 { hasSeenOnboarding = true } }
                )) {
                    OnboardingView(isPresented: .init(
                        get: { !hasSeenOnboarding },
                        set: { if !$0 { hasSeenOnboarding = true } }
                    ))
                }
        }
    }
}
