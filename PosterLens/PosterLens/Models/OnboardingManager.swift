import SwiftUI
import Combine

/// Manages the onboarding experience for the PosterLens app
class OnboardingManager: ObservableObject {
    // Master switch to enable/disable the entire onboarding system
    let onboardingEnabled = false  // Set to false to disable all onboarding features
    
    // Published properties to control hint visibility
    @Published var showCameraHint = false
    @Published var showPermissionHint = false
    @Published var showHistoryHint = false
    
    // Key for UserDefaults to track if user has completed onboarding
    private let onboardingCompletedKey = "onboardingCompleted"
    
    init() {
        // If onboarding is disabled, don't show any hints
        if !onboardingEnabled {
            showCameraHint = false
            showPermissionHint = false
            showHistoryHint = false
            return
        }
        
        // Check if this is the first launch
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        
        if !hasCompletedOnboarding {
            // Show camera hint immediately on first launch
            showCameraHint = true
            
            // Schedule other hints to appear sequentially
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.showCameraHint = false
            }
        }
    }
    
    /// Shows the permission hint when the camera is activated
    func showPermissionHintIfNeeded() {
        // Skip if onboarding is disabled
        if !onboardingEnabled { return }
        
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        if !hasCompletedOnboarding {
            showPermissionHint = true
            
            // Auto-dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.showPermissionHint = false
            }
        }
    }
    
    /// Shows the history hint after completing a scan
    func showHistoryHintIfNeeded() {
        // Skip if onboarding is disabled
        if !onboardingEnabled { return }
        
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        if !hasCompletedOnboarding {
            showHistoryHint = true
            
            // Auto-dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.showHistoryHint = false
                
                // Mark onboarding as completed after showing all hints
                UserDefaults.standard.set(true, forKey: self?.onboardingCompletedKey ?? "")
            }
        }
    }
    
    /// Manually dismisses a hint
    func dismissHint(hint: HintType) {
        // Skip if onboarding is disabled
        if !onboardingEnabled { return }
        
        switch hint {
        case .camera:
            showCameraHint = false
        case .permission:
            showPermissionHint = false
        case .history:
            showHistoryHint = false
            // Mark onboarding as completed if user manually dismisses the last hint
            UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        }
    }
    
    /// Resets onboarding status (for testing)
    func resetOnboarding() {
        // Skip if onboarding is disabled
        if !onboardingEnabled { return }
        
        UserDefaults.standard.set(false, forKey: onboardingCompletedKey)
        showCameraHint = true
    }
    
    /// Types of hints available in the app
    enum HintType {
        case camera
        case permission
        case history
    }
}

/// Reusable tooltip view for onboarding hints
struct TooltipView: View {
    let text: String
    let arrowPosition: ArrowPosition
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if arrowPosition == .top {
                Triangle()
                    .fill(Color(.systemBlue))
                    .frame(width: 20, height: 10)
                    .padding(.leading, 20)
            }
            
            HStack {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                
                Spacer()
                
                Button(action: action) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.trailing, 12)
                }
            }
            .background(Color(.systemBlue))
            .cornerRadius(8)
            
            if arrowPosition == .bottom {
                Triangle(direction: .down)
                    .fill(Color(.systemBlue))
                    .frame(width: 20, height: 10)
                    .padding(.leading, 20)
            }
        }
        .padding(.horizontal)
    }
    
    enum ArrowPosition {
        case top
        case bottom
        case none
    }
}

/// Triangle shape for tooltip arrows
struct Triangle: Shape {
    var direction: Direction = .up
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        case .down:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
        
        return path
    }
    
    enum Direction {
        case up
        case down
    }
}
