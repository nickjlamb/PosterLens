import SwiftUI

/// A design system to ensure consistent spacing, colors, and typography throughout the app
struct DesignSystem {
    // MARK: - Spacing Constants
    
    struct Spacing {
        /// Tiny space for very tight controls (4pt)
        static let tiny: CGFloat = 4
        
        /// Extra small space for tight controls (8pt)
        static let extraSmall: CGFloat = 8
        
        /// Small space for related controls (12pt)
        static let small: CGFloat = 12
        
        /// Medium space for separate controls (16pt)
        static let medium: CGFloat = 16
        
        /// Large space for group separation (24pt)
        static let large: CGFloat = 24
        
        /// Extra large space for major section separation (32pt)
        static let extraLarge: CGFloat = 32
        
        /// Huge space for extreme separation (48pt)
        static let huge: CGFloat = 48
        
        /// Standard content padding (16pt)
        static let contentPadding: CGFloat = 16
        
        /// Standard list row padding (16pt vertical, 20pt horizontal)
        static let listRowPadding = EdgeInsets(
            top: 16, leading: 20, bottom: 16, trailing: 20
        )
        
        /// Standard card padding (16pt)
        static let cardPadding: CGFloat = 16
        
        /// Standard form field spacing (12pt)
        static let formFieldSpacing: CGFloat = 12
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        /// Small radius (4pt) for subtle rounding
        static let small: CGFloat = 4
        
        /// Medium radius (8pt) for buttons and inputs
        static let medium: CGFloat = 8
        
        /// Large radius (12pt) for cards
        static let large: CGFloat = 12
        
        /// Extra large radius (20pt) for prominent elements
        static let extraLarge: CGFloat = 20
        
        /// Full circle
        static let full: CGFloat = .infinity
    }
    
    // MARK: - Shadow
    
    struct Shadow {
        /// Small shadow for subtle elevation
        static let small = ShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        
        /// Medium shadow for cards
        static let medium = ShadowStyle(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        
        /// Large shadow for elevated components
        static let large = ShadowStyle(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        
        /// Shadow style for standard cards
        static let card = ShadowStyle(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    /// Shadow style definition
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.cardPadding)
            .background(Color(.systemBackground))
            .cornerRadius(DesignSystem.CornerRadius.large)
            .shadow(
                color: DesignSystem.Shadow.card.color,
                radius: DesignSystem.Shadow.card.radius,
                x: DesignSystem.Shadow.card.x,
                y: DesignSystem.Shadow.card.y
            )
    }
    
    /// Apply a consistent shadow style
    func shadowStyle(_ style: DesignSystem.ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}