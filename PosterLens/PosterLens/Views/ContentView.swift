import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var selectedTab = 0
    // Removed test panel
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                CameraView()
                    .tabItem {
                        Label("Scan", systemImage: "viewfinder")
                    }
                    .tag(0)
                
                ImprovedHistoryView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }
                    .tag(1)
            }
            .accentColor(.blue)  // Make tab items more visible
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowHistory"))) { _ in
                selectedTab = 1
            }
            .onAppear {
                // Configure navigation bar for the white/native design: dark title, brand-blue controls
                let brandBlueUI = UIColor(red: 0.17, green: 0.45, blue: 0.87, alpha: 1)
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithTransparentBackground()
                navBarAppearance.backgroundColor = .clear
                navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
                navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

                // Apply navigation bar appearance globally
                UINavigationBar.appearance().standardAppearance = navBarAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
                UINavigationBar.appearance().compactAppearance = navBarAppearance
                UINavigationBar.appearance().tintColor = brandBlueUI

                // Customize tab bar appearance
                let tabBarAppearance = UITabBarAppearance()
                tabBarAppearance.configureWithOpaqueBackground()

                // Solid (non-transparent) footer so scrolling content doesn't bleed through
                tabBarAppearance.backgroundColor = UIColor.systemBackground

                // Add a subtle shadow for better visibility
                tabBarAppearance.shadowColor = UIColor.black.withAlphaComponent(0.3)
                tabBarAppearance.shadowImage = UIImage()

                // Customize the selected and unselected item appearance
                let selectedAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.systemBlue,
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
                ]

                let normalAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.darkGray,
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular)
                ]

                tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
                tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes

                // Make the icons more visible
                tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
                tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.darkGray

                // Apply the tab bar appearance
                UITabBar.appearance().standardAppearance = tabBarAppearance
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
            
            // History hint tooltip
            if onboardingManager.showHistoryHint {
                VStack {
                    Spacer()
                    TooltipView(
                        text: "Tap the History tab to view your saved poster summaries",
                        arrowPosition: .bottom
                    ) {
                        onboardingManager.dismissHint(hint: .history)
                    }
                    .padding(.bottom, 60) // Position above tab bar
                    .transition(.opacity)
                    .animation(.easeInOut, value: onboardingManager.showHistoryHint)
                }
                .zIndex(1) // Ensure tooltip appears above other content
            }
        }
    }
}
