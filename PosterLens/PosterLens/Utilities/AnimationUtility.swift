import SwiftUI

struct AnimationUtility {
    // Standard animation durations
    static let quickDuration: Double = 0.2
    static let standardDuration: Double = 0.3
    static let longDuration: Double = 0.5
    
    // Standard animation curves
    static let buttonScale: Animation = .spring(response: 0.3, dampingFraction: 0.7)
    static let fadeInOut: Animation = .easeInOut(duration: standardDuration)
    static let slideIn: Animation = .spring(response: 0.4, dampingFraction: 0.8)
    static let smoothReveal: Animation = .interpolatingSpring(mass: 1.0, stiffness: 100, damping: 16, initialVelocity: 0)
    static let gentle: Animation = .easeOut(duration: standardDuration)
}

// MARK: - View Extensions

extension View {
    // Button press animation
    func buttonPressAnimation(scale: CGFloat = 0.95) -> some View {
        self.buttonStyle(PressEffectButtonStyle(scale: scale))
    }
    
    // Gentle hover effect for cards
    @ViewBuilder func hoverEffect(enabled: Bool = true) -> some View {
        if enabled {
            self.modifier(HoverEffectViewModifier())
        } else {
            self
        }
    }
    
    // Subtle shimmer effect for loading states
    func shimmer(enabled: Bool = true, speed: Double = 1.0) -> some View {
        self.modifier(ShimmerEffectModifier(enabled: enabled, speed: speed))
    }
    
    // Pulsing animation for emphasis
    func pulseEffect(enabled: Bool = true, duration: Double = 1.5) -> some View {
        self.modifier(PulseEffectModifier(enabled: enabled, duration: duration))
    }
    
    // Entrance animation from bottom
    func slideUpOnAppear(delay: Double = 0, enabled: Bool = true) -> some View {
        self.modifier(SlideUpAppearModifier(delay: delay, enabled: enabled))
    }
    
    // Entrance animation from right
    func slideInFromRight(delay: Double = 0, enabled: Bool = true) -> some View {
        self.modifier(SlideInFromRightModifier(delay: delay, enabled: enabled))
    }
    
    // Fade in animation
    func fadeInOnAppear(delay: Double = 0, duration: Double = AnimationUtility.standardDuration) -> some View {
        self.modifier(FadeInModifier(delay: delay, duration: duration))
    }
}

// MARK: - Button Style

struct PressEffectButtonStyle: ButtonStyle {
    let scale: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(AnimationUtility.buttonScale, value: configuration.isPressed)
    }
}

// MARK: - Animation Modifiers

struct HoverEffectViewModifier: ViewModifier {
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? 1.02 : 1)
            .shadow(color: Color.black.opacity(isHovering ? 0.1 : 0.05), 
                    radius: isHovering ? 8 : 5,
                    x: 0, y: isHovering ? 4 : 2)
            .animation(AnimationUtility.gentle, value: isHovering)
            .onAppear {
                withAnimation(AnimationUtility.gentle.repeatForever(autoreverses: true).delay(Double.random(in: 0...2))) {
                    isHovering.toggle()
                }
            }
    }
}

struct ShimmerEffectModifier: ViewModifier {
    let enabled: Bool
    let speed: Double
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .overlay(
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: phase - 0.3),
                                        .init(color: .white.opacity(0.5), location: phase),
                                        .init(color: .clear, location: phase + 0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .mask(content)
                            .blendMode(.screen)
                    }
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5 / speed).repeatForever(autoreverses: false)) {
                        phase = 1.0
                    }
                }
        } else {
            content
        }
    }
}

struct PulseEffectModifier: ViewModifier {
    let enabled: Bool
    let duration: Double
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .scaleEffect(scale)
                .opacity(2 - scale)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        scale = 1.05
                    }
                }
        } else {
            content
        }
    }
}

struct SlideUpAppearModifier: ViewModifier {
    let delay: Double
    let enabled: Bool
    @State private var yOffset: CGFloat = 20
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .offset(y: yOffset)
                .opacity(opacity)
                .onAppear {
                    withAnimation(AnimationUtility.slideIn.delay(delay)) {
                        yOffset = 0
                        opacity = 1
                    }
                }
        } else {
            content
        }
    }
}

struct SlideInFromRightModifier: ViewModifier {
    let delay: Double
    let enabled: Bool
    @State private var xOffset: CGFloat = 20
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        if enabled {
            content
                .offset(x: xOffset)
                .opacity(opacity)
                .onAppear {
                    withAnimation(AnimationUtility.slideIn.delay(delay)) {
                        xOffset = 0
                        opacity = 1
                    }
                }
        } else {
            content
        }
    }
}

struct FadeInModifier: ViewModifier {
    let delay: Double
    let duration: Double
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: duration).delay(delay)) {
                    opacity = 1
                }
            }
    }
}