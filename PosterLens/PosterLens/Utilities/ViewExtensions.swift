import SwiftUI

// MARK: - Button Style Extensions for Premium UX

/// A button style that provides smooth scale animation and haptic feedback
struct PremiumButtonStyle: ButtonStyle {
    var hapticStyle: HapticManager.HapticStyle = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                if newValue {
                    // Haptic feedback on press
                    switch hapticStyle {
                    case .light:
                        HapticManager.shared.lightImpact()
                    case .medium:
                        HapticManager.shared.mediumImpact()
                    case .heavy:
                        HapticManager.shared.heavyImpact()
                    case .selection:
                        HapticManager.shared.selection()
                    }
                }
            }
    }
}

/// A prominent button style for primary actions
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.medium)
            .background(
                isEnabled
                    ? DesignSystem.Colors.brandGradient
                    : LinearGradient(
                        colors: [Color.gray.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
            )
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                if newValue && isEnabled {
                    HapticManager.shared.mediumImpact()
                }
            }
            .opacity(isEnabled ? 1.0 : 0.6)
    }
}

/// A secondary button style for less prominent actions
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(DesignSystem.Colors.brandBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.brandBlue, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                if newValue {
                    HapticManager.shared.lightImpact()
                }
            }
    }
}

// MARK: - View Extension Helpers

extension View {
    /// Apply premium button style with haptic feedback
    func premiumButtonStyle(haptic: HapticManager.HapticStyle = .light) -> some View {
        self.buttonStyle(PremiumButtonStyle(hapticStyle: haptic))
    }

    /// Apply primary button styling
    func primaryButtonStyle(isEnabled: Bool = true) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
    }

    /// Apply secondary button styling
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
}

// MARK: - Haptic Manager Extension

extension HapticManager {
    enum HapticStyle {
        case light
        case medium
        case heavy
        case selection
    }
}
