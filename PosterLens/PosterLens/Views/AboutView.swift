import SwiftUI
import MessageUI
import UIKit

// App Icon View that uses the appicon from the asset catalog
struct AppIconView: View {
    var body: some View {
        // Use the standalone appicon that we copied to its own image set
        Image("appicon")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct AboutView: View {
    // Background gradient colors
    @State private var gradientColors: [Color] = [
        Color.accentColor.opacity(0.8),
        Color.accentColor.opacity(0.2)
    ]
    
    // App version and build number
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
    // URLs for links
    private let websiteURL = URL(string: "https://www.pharmatools.ai")!
    private let privacyPolicyURL = URL(string: "https://www.pharmatools.ai/privacy-policy")!
    private let termsOfUseURL = URL(string: "https://www.pharmatools.ai/terms")!
    private let supportEmail = "info@pharmatools.ai"
    
    // Other app URLs
    private let patientlyAIURL = URL(string: "https://apps.apple.com/us/app/patiently-ai-simplify-notes/id6739538685")!
    private let medCheckrURL = URL(string: "https://apps.apple.com/us/app/patiently-ai-simplify-notes/id6741887343")!
    private let trialGenURL = URL(string: "https://apps.apple.com/us/app/patiently-ai-simplify-notes/id6743369813")!
    
    // App icons
    private let patientlyAIIcon = "PatientlyAI"
    private let medCheckrIcon = "MedCheckr"
    private let trialGenIcon = "TrialGen"
    
    // State for showing mail compose sheet
    @State private var showingMailCompose = false
    // No longer need the resetOnboardingToggle state
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    // Main content container
                    ZStack(alignment: .top) {
                        // Decorative elements positioned absolutely
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .blur(radius: 30)
                            .offset(x: -150, y: 50)
                            .zIndex(0)
                        
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 300, height: 300)
                            .blur(radius: 40)
                            .offset(x: 150, y: 400)
                            .zIndex(0)
                            
                        // Content
                        VStack(spacing: 32) {
                            Spacer(minLength: 0)
                            // App Header Section
                            VStack(spacing: 16) {
                                AppIconView()
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                    )
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 150, height: 150)
                                            .blur(radius: 10)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                                
                                Text("PosterLens")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                                
                                Text(appVersion)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding(.top, 0)
                            .padding(.bottom, 10)
                            
                            // Feature Cards
                            VStack(spacing: 16) {
                                featureCard(
                                    icon: "doc.viewfinder",
                                    title: "Scan Scientific Posters",
                                    description: "Quickly capture and analyze research posters at conferences"
                                )
                                
                                featureCard(
                                    icon: "brain.head.profile",
                                    title: "AI-Powered Summaries",
                                    description: "Generate concise summaries and questions for the author"
                                )
                                
                                featureCard(
                                    icon: "square.and.arrow.down",
                                    title: "Export & Share",
                                    description: "Save and share insights with colleagues"
                                )
                            }
                            .padding(.horizontal)
                            
                            // Support & Legal Section
                            VStack(spacing: 4) {
                                Text("Support & Legal")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                                
                                VStack(spacing: 0) {
                                    linkButton(label: "Contact Support", icon: "envelope", secondaryText: supportEmail) {
                                        composeEmail()
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 50)
                                    
                                    linkButton(label: "Privacy Policy", icon: "lock.shield") {
                                        openURL(privacyPolicyURL)
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 50)
                                    
                                    linkButton(label: "Terms of Use", icon: "doc.text") {
                                        openURL(termsOfUseURL)
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 50)
                                    
                                    // Reset Onboarding Toggle
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.accentColor.opacity(0.9))
                                            .frame(width: 26)
                                        
                                        Text("Reset Onboarding")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(UIColor.darkText))
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            // Reset onboarding
                                            onboardingManager.resetOnboarding()
                                            
                                            // Haptic feedback
                                            HapticManager.shared.success()
                                            
                                            // Show confirmation alert using SwiftUI alert instead of UIKit
                                            DispatchQueue.main.async {
                                                let impactGenerator = UINotificationFeedbackGenerator()
                                                impactGenerator.notificationOccurred(.success)
                                                
                                                // Display a temporary toast message
                                                let toastMessage = "Onboarding has been reset"
                                                let toast = UIAlertController(title: nil, message: toastMessage, preferredStyle: .alert)
                                                UIApplication.shared.connectedScenes
                                                    .filter { $0.activationState == .foregroundActive }
                                                    .first(where: { $0 is UIWindowScene })
                                                    .flatMap { $0 as? UIWindowScene }?.windows
                                                    .first(where: { $0.isKeyWindow })?
                                                    .rootViewController?
                                                    .present(toast, animated: true)
                                                
                                                // Dismiss after brief delay
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                    toast.dismiss(animated: true)
                                                }
                                            }
                                        }) {
                                            Text("Reset")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.accentColor)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.95))
                                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                )
                                .padding(.horizontal)
                            }
                            
                            // More Apps Section
                            VStack(spacing: 4) {
                                Text("More from PharmaTools.AI")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                                
                                VStack(spacing: 0) {
                                    appLinkButtonWithImage(
                                        label: "Patiently AI", 
                                        imageName: patientlyAIIcon,
                                        description: "Turn complex medical notes into patient-friendly explanations in seconds"
                                    ) {
                                        openURL(patientlyAIURL)
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 50)
                                    
                                    appLinkButtonWithImage(
                                        label: "MedCheckr ABPI", 
                                        imageName: medCheckrIcon,
                                        description: "Ensure your pharmaceutical claims comply with the ABPI Code of Practice instantly"
                                    ) {
                                        openURL(medCheckrURL)
                                    }
                                    
                                    Divider()
                                        .padding(.leading, 50)
                                    
                                    appLinkButtonWithImage(
                                        label: "TrialGen", 
                                        imageName: trialGenIcon,
                                        description: "Need the perfect name for your clinical trial? Try TrialGen!"
                                    ) {
                                        openURL(trialGenURL)
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.95))
                                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                )
                                .padding(.horizontal)
                            }
                            
                            // Copyright Section with logo
                            VStack(spacing: 16) {
                                Button(action: {
                                    openURL(websiteURL)
                                }) {
                                    Image("PharmaToolsLogo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 40)
                                }
                                
                                Text("© 2025 PharmaTools.AI")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.vertical, 16)
                            .padding(.bottom, 30)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingMailCompose) {
                MailView(
                    subject: "PosterLens Support Request",
                    recipients: [supportEmail],
                    messageBody: "Hello PharmaTools.AI Support,\n\n"
                )
            }
        }
    }
    
    private func featureCard(icon: String, title: String, description: String) -> some View {
        // Randomized subtle gradient angle for each card
        let angle = Double.random(in: 0...360)
        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)]),
                                center: .center,
                                angle: .degrees(angle)
                            )
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(UIColor.darkText))
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(UIColor.darkText))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
        )
    }
    
    private func linkButton(label: String, icon: String, secondaryText: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentColor.opacity(0.9))
                    .frame(width: 26)
                
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(UIColor.darkText))
                
                Spacer()
                
                if let secondaryText = secondaryText {
                    Text(secondaryText)
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.darkText))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.gray.opacity(0.7))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func appLinkButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentColor.opacity(0.9))
                    .frame(width: 26)
                
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(UIColor.darkText))
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundColor(Color.gray.opacity(0.7))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func appLinkButtonWithImage(label: String, imageName: String, description: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .frame(height: description.isEmpty ? 56 : 64)
                
                HStack {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(UIColor.darkText))
                        
                        if !description.isEmpty {
                            Text(description)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(UIColor.darkGray))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 16))
                        .foregroundColor(Color(UIColor.darkText))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func composeEmail() {
        // Check if mail can be sent
        if MFMailComposeViewController.canSendMail() {
            showingMailCompose = true
        } else {
            // Fallback to opening mail app with URL scheme
            let emailURL = URL(string: "mailto:\(supportEmail)?subject=PosterLens%20Support%20Request")!
            openURL(emailURL)
        }
    }
}

// Mail view for composing emails
struct MailView: UIViewControllerRepresentable {
    let subject: String
    let recipients: [String]
    let messageBody: String
    
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let viewController = MFMailComposeViewController()
        viewController.mailComposeDelegate = context.coordinator
        viewController.setSubject(subject)
        viewController.setToRecipients(recipients)
        viewController.setMessageBody(messageBody, isHTML: false)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailView
        
        init(_ parent: MailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Preview provider
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
