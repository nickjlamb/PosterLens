import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @Binding var isPresented: Bool
    
    // Track the current page
    @State private var currentPage = 0
    
    // Onboarding data
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to PosterLens",
            image: "doc.viewfinder",
            description: "Scan scientific posters to quickly analyze and extract key information.",
            backgroundColor: .blue
        ),
        OnboardingPage(
            title: "Scan a Poster",
            image: "camera.fill",
            description: "Point your camera at a scientific poster and PosterLens will analyze the text.",
            backgroundColor: .purple
        ),
        OnboardingPage(
            title: "Get Insights",
            image: "lightbulb.fill",
            description: "Discover key takeaways, research questions, and future directions from the poster.",
            backgroundColor: .green
        ),
        OnboardingPage(
            title: "Save for Later",
            image: "doc.text.fill",
            description: "All your scanned posters are saved for future reference and can be shared.",
            backgroundColor: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            // Background color that transitions between pages
            if currentPage < pages.count {
                pages[currentPage].backgroundColor
                    .edgesIgnoringSafeArea(.all)
                    .animation(.easeInOut, value: currentPage)
            }
            
            // Main content
            VStack(spacing: 0) {
                // Skip button at the top
                HStack {
                    Spacer()
                    
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("Skip")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().stroke(Color.white, lineWidth: 2))
                    }
                    .buttonPressAnimation()
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                .padding(.bottom, 20)
                
                // Use TabView for swipeable pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 40) {
                            // Image for current page
                            Image(systemName: pages[index].image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 150, height: 150)
                                .foregroundColor(.white)
                                .padding()
                            
                            // Page title
                            Text(pages[index].title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                            
                            // Page description
                            Text(pages[index].description)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentPage) { newPage in
                    HapticManager.shared.selection()
                }
                
                Spacer()
                
                // Page indicator dots
                HStack(spacing: 12) {
                    ForEach(0..<pages.count, id: \.self) { page in
                        Circle()
                            .fill(currentPage == page ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 10, height: 10)
                            .scaleEffect(currentPage == page ? 1.2 : 1.0)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
                
                // Button to advance or complete
                Button(action: {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                        HapticManager.shared.selection()
                    } else {
                        completeOnboarding()
                    }
                }) {
                    HStack {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                            .fontWeight(.bold)
                        
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(pages[currentPage].backgroundColor)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(Color.white))
                }
                .buttonPressAnimation()
                .padding(.bottom, 50)
            }
        }
    }
    
    private func completeOnboarding() {
        HapticManager.shared.success()
        onboardingManager.completeOnboarding()
        isPresented = false
    }
}

// Model for onboarding page data
struct OnboardingPage {
    let title: String
    let image: String
    let description: String
    let backgroundColor: Color
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
            .environmentObject(OnboardingManager())
    }
}