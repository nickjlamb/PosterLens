import SwiftUI

@main
struct PosterLensApp: App {
    @StateObject private var dataStore = DataStore()
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(dataStore)
                    .environmentObject(onboardingManager)
                    .onAppear {
                        // Check if we need to show onboarding
                        showOnboarding = onboardingManager.showOnboarding
                    }
                
                // Show onboarding as a fullscreen cover when needed
                if showOnboarding {
                    OnboardingView(isPresented: $showOnboarding)
                        .environmentObject(onboardingManager)
                        .transition(.opacity)
                        .zIndex(1) // Ensure it appears on top
                }
            }
            .animation(.easeInOut, value: showOnboarding)
        }
    }
}
