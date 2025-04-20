import SwiftUI

/// A view that displays a test interface for the onboarding experience
struct OnboardingTestView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Onboarding Test Panel")
                .font(.title)
                .padding(.top, 30)
            
            Divider()
            
            Button("Reset Onboarding Status") {
                onboardingManager.resetOnboarding()
            }
            .buttonStyle(.borderedProminent)
            
            Divider()
            
            Text("Show Individual Hints:")
                .font(.headline)
            
            Button("Show Camera Hint") {
                onboardingManager.showCameraHint = true
            }
            .buttonStyle(.bordered)
            
            Button("Show Permission Hint") {
                onboardingManager.showPermissionHint = true
            }
            .buttonStyle(.bordered)
            
            Button("Show History Hint") {
                onboardingManager.showHistoryHint = true
            }
            .buttonStyle(.bordered)
            
            Divider()
            
            Text("Current Hint Status:")
                .font(.headline)
            
            HStack {
                Text("Camera Hint:")
                Spacer()
                Text(onboardingManager.showCameraHint ? "Visible" : "Hidden")
                    .foregroundColor(onboardingManager.showCameraHint ? .green : .red)
            }
            .padding(.horizontal)
            
            HStack {
                Text("Permission Hint:")
                Spacer()
                Text(onboardingManager.showPermissionHint ? "Visible" : "Hidden")
                    .foregroundColor(onboardingManager.showPermissionHint ? .green : .red)
            }
            .padding(.horizontal)
            
            HStack {
                Text("History Hint:")
                Spacer()
                Text(onboardingManager.showHistoryHint ? "Visible" : "Hidden")
                    .foregroundColor(onboardingManager.showHistoryHint ? .green : .red)
            }
            .padding(.horizontal)
            
            Spacer()
            
            Text("Note: This test panel is for development only")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding()
        .environmentObject(onboardingManager)
    }
}

#Preview {
    OnboardingTestView()
}
