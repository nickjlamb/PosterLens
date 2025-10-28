import SwiftUI
import MessageUI
import UIKit

// App Icon View that uses the appicon from the asset catalog
struct AppIconView: View {
    var body: some View {
        // Use the standalone appicon that we copied to its own image set
        ZStack {
            // Static glow effect
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 140, height: 140)
                .blur(radius: 20)
                .opacity(0.7)
            
            // App icon without animations
            Image("appicon")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

// Define a preference key for scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct AboutView: View {
    
    // App version and build number
    private var appVersion: String {
        let version = "1.3" // Updated version number
        let build = "5" // Updated build number
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
    
    // Animation states
    @State private var scrollOffset: CGFloat = 0
    @State private var appearAnimation = false
    @State private var showCards = false
    @State private var showLinks = false
    @State private var showMoreApps = false
    @State private var showFooter = false
    
    // Other state variables
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        aboutContent
    }
    
    // Break up the body into smaller views to help compiler
    private var aboutContent: some View {
        NavigationView {
            ZStack {
                backgroundView
                
                ScrollView {
                    scrollOffsetTracker
                    mainContentView
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    doneButton
                }
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                self.scrollOffset = value
            }
            .onAppear {
                animateSequentially()
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
    
    // Background view with gradient and decorative elements
    private var backgroundView: some View {
        ZStack {
            DesignSystem.Colors.brandGradient
                .ignoresSafeArea()
                
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 30)
                .offset(x: -150 + scrollOffset * 0.2, y: 50 - scrollOffset * 0.1)
            
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 150 - scrollOffset * 0.1, y: 400 - scrollOffset * 0.25)
        }
    }
    
    // Scroll offset tracker
    private var scrollOffsetTracker: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .global).minY)
        }
        .frame(height: 0)
    }
    
    // Main content sections
    private var mainContentView: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)
            headerSection
            featureCardsSection
            supportSection
            moreAppsSection
            footerSection
        }
        .padding()
    }
    
    // App header section with logo and version
    private var headerSection: some View {
        VStack(spacing: 16) {
            AppIconView()
                .frame(width: 120, height: 120)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                .offset(y: appearAnimation ? 0 : -20)
                .opacity(appearAnimation ? 1.0 : 0.0)
            
            Text("PosterLens")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                .offset(y: appearAnimation ? 0 : 10)
                .opacity(appearAnimation ? 1.0 : 0.0)
            
            Text(appVersion)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.1))
                .cornerRadius(12)
                .offset(y: appearAnimation ? 0 : 10)
                .opacity(appearAnimation ? 1.0 : 0.0)
        }
        .padding(.top, 0)
        .padding(.bottom, 10)
    }
    
    // Feature cards section
    private var featureCardsSection: some View {
        VStack(spacing: 16) {
            featureCard(
                icon: "doc.viewfinder",
                title: "Scan Scientific Posters",
                description: "Quickly capture and analyze research posters at conferences"
            )
            .offset(x: showCards ? 0 : -30)
            .opacity(showCards ? 1.0 : 0.0)
            
            featureCard(
                icon: "brain.head.profile",
                title: "AI-Powered Summaries",
                description: "Generate concise summaries and questions for the author"
            )
            .offset(x: showCards ? 0 : -30)
            .opacity(showCards ? 1.0 : 0.0)
            
            featureCard(
                icon: "square.and.arrow.down",
                title: "Export & Share",
                description: "Save and share insights with colleagues"
            )
            .offset(x: showCards ? 0 : -30)
            .opacity(showCards ? 1.0 : 0.0)
        }
        .padding(.horizontal)
    }
    
    // Support and legal section
    private var supportSection: some View {
        supportSectionContent
    }
    
    // Support section content (further broken down)
    private var supportSectionContent: some View {
        VStack(spacing: 4) {
            Text("Support & Legal")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            supportLinksAndButtons
        }
    }
    
    // Support links and buttons
    private var supportLinksAndButtons: some View {
        VStack(spacing: 0) {
            // Contact Support Button
            contactSupportButton
            
            Divider().padding(.leading, 50)
            
            // Privacy Policy Button
            privacyPolicyButton
            
            Divider().padding(.leading, 50)
            
            // Terms of Use Button
            termsButton
            
            Divider().padding(.leading, 50)
            
            // Reset Onboarding Toggle
            resetOnboardingRow
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
        .offset(y: showLinks ? 0 : 20)
        .opacity(showLinks ? 1.0 : 0.0)
    }
    
    // Contact support button
    private var contactSupportButton: some View {
        Button(action: { composeEmail() }) {
            HStack {
                Image(systemName: "envelope")
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentColor.opacity(0.9))
                    .frame(width: 26)
                
                Text("Contact Support")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(UIColor.darkText))
                
                Spacer()
                
                Text(supportEmail)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.darkText))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Privacy policy button
    private var privacyPolicyButton: some View {
        Button(action: { openURL(privacyPolicyURL) }) {
            HStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentColor.opacity(0.9))
                    .frame(width: 26)
                
                Text("Privacy Policy")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(UIColor.darkText))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.gray.opacity(0.7))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Terms of use button
    private var termsButton: some View {
        Button(action: { openURL(termsOfUseURL) }) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentColor.opacity(0.9))
                    .frame(width: 26)
                
                Text("Terms of Use")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(UIColor.darkText))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.gray.opacity(0.7))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Reset onboarding row
    private var resetOnboardingRow: some View {
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
                
                // Show confirmation alert
                showResetConfirmation()
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
    
    // Show reset confirmation
    private func showResetConfirmation() {
        DispatchQueue.main.async {
            let impactGenerator = UINotificationFeedbackGenerator()
            impactGenerator.notificationOccurred(.success)
            
            // Display a temporary toast message
            let toastMessage = "Onboarding has been reset"
            let toast = UIAlertController(title: nil, message: toastMessage, preferredStyle: .alert)
            UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController?
                .present(toast, animated: true)
            
            // Dismiss after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                toast.dismiss(animated: true)
            }
        }
    }
    
    // More apps section
    private var moreAppsSection: some View {
        VStack(spacing: 4) {
            Text("More from PharmaTools.AI")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .opacity(showMoreApps ? 1.0 : 0.0)
            
            moreAppsButtons
        }
    }
    
    // More apps buttons container
    private var moreAppsButtons: some View {
        VStack(spacing: 0) {
            patientlyButton
            
            Divider().padding(.leading, 50)
            
            medCheckrButton
            
            Divider().padding(.leading, 50)
            
            trialGenButton
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
        .offset(y: showMoreApps ? 0 : 30)
        .opacity(showMoreApps ? 1.0 : 0.0)
    }
    
    // Patiently AI app button
    private var patientlyButton: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            openURL(patientlyAIURL)
        }) {
            appButtonContent(
                icon: patientlyAIIcon,
                title: "Patiently AI",
                description: "Turn complex medical notes into patient-friendly explanations in seconds"
            )
        }
        .offset(x: showMoreApps ? 0 : 50)
        .opacity(showMoreApps ? 1.0 : 0.0)
    }
    
    // MedCheckr app button
    private var medCheckrButton: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            openURL(medCheckrURL)
        }) {
            appButtonContent(
                icon: medCheckrIcon,
                title: "MedCheckr ABPI",
                description: "Ensure your pharmaceutical claims comply with the ABPI Code of Practice instantly"
            )
        }
        .offset(x: showMoreApps ? 0 : 50)
        .opacity(showMoreApps ? 1.0 : 0.0)
    }
    
    // TrialGen app button
    private var trialGenButton: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            openURL(trialGenURL)
        }) {
            appButtonContent(
                icon: trialGenIcon,
                title: "TrialGen",
                description: "Need the perfect name for your clinical trial? Try TrialGen!"
            )
        }
        .offset(x: showMoreApps ? 0 : 50)
        .opacity(showMoreApps ? 1.0 : 0.0)
    }
    
    // Reusable app button content
    private func appButtonContent(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top) {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(UIColor.darkText))
                
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(UIColor.darkGray))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 16))
                .foregroundColor(Color(UIColor.darkText))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
    
    // Footer section with copyright
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                HapticManager.shared.lightImpact()
                openURL(websiteURL)
            }) {
                Image("PharmaToolsLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                    .opacity(showFooter ? 1.0 : 0.0)
            }
            
            Text("© 2025 PharmaTools.AI")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .opacity(showFooter ? 1.0 : 0.0)
        }
        .padding(.vertical, 16)
        .padding(.bottom, 30)
        .opacity(showFooter ? 1.0 : 0.0)
    }
    
    // Done button
    private var doneButton: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            dismiss()
        }) {
            Text("Done")
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
    
    // Feature card helper
    private func featureCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon with circle background
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            // Title and description
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
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                )
        )
        .onTapGesture {
            HapticManager.shared.lightImpact()
        }
    }
    
    // Helper method to schedule animations sequentially
    private func animateSequentially() {
        withAnimation(Animation.easeOut(duration: 0.6)) {
            appearAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                showCards = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showLinks = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation {
                showMoreApps = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation {
                showFooter = true
            }
        }
    }
    
    // Email composer helper
    private func composeEmail() {
        if MFMailComposeViewController.canSendMail() {
            showingMailCompose = true
        } else {
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