import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var selectedTab = 0
    @State private var showingAboutView = false
    // Removed test panel
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                CameraView()
                    .tabItem {
                        Label("Scan", systemImage: "camera")
                    }
                    .tag(0)
                
                NavigationView {
                    ImprovedHistoryView(selectedTab: $selectedTab)
                        .navigationBarItems(trailing:
                            Button(action: {
                                showingAboutView = true
                            }) {
                                Image(systemName: "info.circle")
                            }
                        )
                }
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)
            }
            .accentColor(.blue)  // Make tab items more visible
            .onAppear {
                // Customize tab bar appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                
                // Make the tab bar more visible with a semi-transparent background
                appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
                
                // Add a subtle shadow for better visibility
                appearance.shadowColor = UIColor.black.withAlphaComponent(0.3)
                appearance.shadowImage = UIImage()
                
                // Customize the selected and unselected item appearance
                let selectedAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.systemBlue,
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
                ]
                
                let normalAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor.darkGray,
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular)
                ]
                
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
                
                // Make the icons more visible
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor.darkGray
                
                // Apply the appearance
                UITabBar.appearance().standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                }
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
        .sheet(isPresented: $showingAboutView) {
            AboutView()
                .environmentObject(onboardingManager)
        }
    }
}
