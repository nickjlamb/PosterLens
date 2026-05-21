import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @Binding var isPresented: Bool

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to PosterLens",
            image: "doc.viewfinder",
            description: "Scan scientific posters and pull out the key points in seconds."
        ),
        OnboardingPage(
            title: "Capture",
            image: "camera.viewfinder",
            description: "Point your camera at a poster — PosterLens reads it and surfaces the key points."
        ),
        OnboardingPage(
            title: "Explore",
            image: "bubble.left.and.bubble.right.fill",
            description: "Ask questions, chat about the findings, and explore related research and future directions."
        ),
        OnboardingPage(
            title: "Saved & Synced",
            image: "icloud.fill",
            description: "Your scans are saved and synced across your devices with iCloud."
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: { completeOnboarding() }) {
                        Text("Skip")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }

                // Swipeable pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 32) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.brandBlue.opacity(0.12))
                                    .frame(width: 150, height: 150)

                                Image(systemName: pages[index].image)
                                    .font(.system(size: 64, weight: .regular))
                                    .foregroundColor(DesignSystem.Colors.brandBlue)
                            }

                            VStack(spacing: 12) {
                                Text(pages[index].title)
                                    .font(.title.bold())
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)

                                Text(pages[index].description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal)
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentPage) { _ in
                    HapticManager.shared.selection()
                }

                // Page indicator dots
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { page in
                        Circle()
                            .fill(currentPage == page ? DesignSystem.Colors.brandBlue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == page ? 1.2 : 1.0)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Advance / complete
                Button(action: {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                        HapticManager.shared.selection()
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(DesignSystem.Colors.brandBlue))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
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
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
            .environmentObject(OnboardingManager())
    }
}
