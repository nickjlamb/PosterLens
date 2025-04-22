import SwiftUI
import AVFoundation

// UIViewControllerRepresentable to bridge UIKit and SwiftUI
struct CameraPreviewViewControllerRepresentable: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    var onCancel: () -> Void
    @Binding var hasPermission: Bool
    
    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let controller = CameraPreviewViewController()
        controller.onImageCaptured = onImageCaptured
        controller.delegate = context.coordinator
        controller.hasPermission = hasPermission
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {
        uiViewController.hasPermission = hasPermission
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraPreviewViewControllerDelegate {
        let parent: CameraPreviewViewControllerRepresentable
        
        init(_ parent: CameraPreviewViewControllerRepresentable) {
            self.parent = parent
        }
        
        func cameraPreviewViewControllerDidCancel(_ controller: CameraPreviewViewController) {
            parent.onCancel()
        }
        
        func cameraPreviewViewControllerDidTogglePermission(_ controller: CameraPreviewViewController, hasPermission: Bool) {
            parent.hasPermission = hasPermission
        }
    }
}

struct CameraView: View {
    @EnvironmentObject private var dataStore: DataStore
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showingScanner = false
    @State private var showingResults = false
    @State private var hasPermission = false
    @State private var animateScanning = false
    @State private var offsetY: CGFloat = 50
    @State private var opacity: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    // Animation properties
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var showMotionGraphics = false
    
    // State to force refresh of recent scans
    @State private var refreshID = UUID()
    
    private let gradient = LinearGradient(
        colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background with subtle gradient
                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.black : Color.white,
                        colorScheme == .dark ? Color.black : Color(UIColor.systemGray6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else {
                    mainCameraView
                }
            }
            // Hide the default navigation title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Empty view to hide the default title
                    Color.clear
                        .frame(width: 0, height: 0)
                }
            }
            .overlay(alignment: .top) {
                // Custom header with more space and larger font
                VStack(spacing: 4) {
                    Spacer().frame(height: 20) // Add space at the top
                    
                    Text("PosterLens")
                        .font(.title.bold())
                        .foregroundColor(Color.blue)
                    
                    Text("Your AI Scientific Conference Companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer().frame(height: 16) // Add space below
                }
                .padding(.top, 10)
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .onAppear {
                // Set dataStore when view appears
                viewModel.dataStore = dataStore
                
                // Start entrance animation
                withAnimation(.easeOut(duration: 0.8)) {
                    offsetY = 0
                    opacity = 1
                }
                
                // Force refresh of recent scans
                refreshID = UUID()
            }
            // Listen for changes to dataStore.savedScans
            .onChange(of: dataStore.savedScans.count) { _ in
                // Force refresh of recent scans
                refreshID = UUID()
            }
        }
    }
    
    // Loading View with animated elements
    private var loadingView: some View {
        VStack(spacing: 30) {
            Text("Analyzing Poster")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            ZStack {
                // Pulsing circle background
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            pulseScale = 1.2
                        }
                    }
                
                // Rotating ring
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(Angle(degrees: rotationAngle))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
                
                // Processing icon
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }
            
            Text("Extracting insights from your scientific poster...")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(0.8)
        }
        .padding()
    }
    
    // Main Camera View
    private var mainCameraView: some View {
        ZStack {
            VStack {
                Spacer()
                
                // Camera button section with cards
                cameraScanCard
                    .offset(y: offsetY)
                    .opacity(opacity)
                
                Spacer()
                
                // Recent scans preview (teaser for history)
                if !dataStore.savedScans.isEmpty {
                    recentScansPreview
                        .padding(.bottom)
                        .offset(y: offsetY)
                        .opacity(opacity)
                        .id(refreshID) // Force refresh when this ID changes
                }
            }
            
            // Camera hint tooltip
            if onboardingManager.showCameraHint {
                VStack {
                    Spacer()
                    TooltipView(
                        text: "Tap here to scan and summarize a scientific poster",
                        arrowPosition: .top
                    ) {
                        onboardingManager.dismissHint(hint: .camera)
                    }
                    .padding(.bottom, 160)
                    .transition(.opacity)
                    .animation(.easeInOut, value: onboardingManager.showCameraHint)
                }
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            ZStack {
                // Permission hint tooltip that appears in camera view
                if onboardingManager.showPermissionHint {
                    VStack {
                        TooltipView(
                            text: "Toggle this switch to confirm you have permission to photograph this poster",
                            arrowPosition: .bottom
                        ) {
                            onboardingManager.dismissHint(hint: .permission)
                        }
                        .padding(.top, 120)
                        .transition(.opacity)
                        .animation(.easeInOut, value: onboardingManager.showPermissionHint)
                        
                        Spacer()
                    }
                    .zIndex(1) // Ensure tooltip appears above camera view
                }
                
                CameraPreviewViewControllerRepresentable(
                    onImageCaptured: { image in
                        // Pass permission status to the view model
                        viewModel.processImage(image, hasPermission: hasPermission)
                        showingScanner = false
                        
                        // Only navigate to results if we have a valid scan
                        if viewModel.currentScan != nil {
                            showingResults = true
                            // Show history hint after completing a scan
                            onboardingManager.showHistoryHintIfNeeded()
                            
                            // Force refresh of recent scans
                            refreshID = UUID()
                        }
                        
                        // Reset permission for next scan
                        hasPermission = false
                    },
                    onCancel: {
                        showingScanner = false
                        // Reset permission for next scan
                        hasPermission = false
                    },
                    hasPermission: $hasPermission
                )
                .ignoresSafeArea()
                
                // Add a subtle highlight at the bottom to make tab bar more visible
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.clear, colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.15)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(height: 40)
                }
                .ignoresSafeArea()
            }
        }
        .navigationDestination(isPresented: $showingResults) {
            if let currentScan = viewModel.currentScan {
                SummaryView(scan: currentScan)
            }
        }
    }
    
    // Camera scan card with animations
    private var cameraScanCard: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                showMotionGraphics = true
            }
            
            // Delayed action to allow animation to run
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingScanner = true
                // Show permission hint when camera is activated
                onboardingManager.showPermissionHintIfNeeded()
                
                // Reset animation state for next use
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showMotionGraphics = false
                }
            }
        }) {
            ZStack {
                // Card background with shadow
                RoundedRectangle(cornerRadius: 24)
                    .fill(colorScheme == .dark ?
                          Color(UIColor.systemGray6) :
                          Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(gradient, lineWidth: showMotionGraphics ? 3 : 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                    .scaleEffect(showMotionGraphics ? 0.96 : 1.0)
                
                VStack(spacing: 24) {
                    // Animated camera icon
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(gradient)
                            .frame(width: 100, height: 100)
                            .scaleEffect(showMotionGraphics ? 1.1 : 1.0)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        // Camera icon
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 12) {
                        Text("Scan Scientific Poster")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        Text("Point your camera at a research poster to capture,\nanalyze, and get instant insights")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Scan button
                    Text("Tap to Scan")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 40)
                        .background(gradient)
                        .cornerRadius(30)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
            }
            .frame(height: 360)
            .padding(.horizontal, 24)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Scan scientific poster")
    }
    
    // Recent scans preview section
    private var recentScansPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Scans")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Use sorted array to ensure most recent scans appear first
                    ForEach(Array(dataStore.savedScans.sorted(by: { $0.date > $1.date }).prefix(5).enumerated()), id: \.element.id) { index, scan in
                        NavigationLink(destination: SummaryView(scan: scan)) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Thumbnail or placeholder in a fixed size container
                                ZStack {
                                    if let image = scan.image {
                                        // Check image orientation
                                        let isLandscape = image.size.width > image.size.height
                                        
                                        if isLandscape {
                                            // For landscape images, we'll center them and maintain aspect ratio
                                            // This ensures they have the same width but might have smaller height
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFit() // Maintain aspect ratio without filling
                                                    .frame(width: 120) // Fixed width
                                                    .frame(height: 80, alignment: .center) // Center in fixed height container
                                                
                                                // Landscape indicator
                                                Image(systemName: "rectangle")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.white)
                                                    .padding(4)
                                                    .background(Color.black.opacity(0.4))
                                                    .cornerRadius(4)
                                                    .padding(4)
                                            }
                                        } else {
                                            // For portrait images, fill the space
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 120, height: 80)
                                                .clipped() // Clip the image to prevent overflow
                                        }
                                    } else {
                                        // Placeholder for missing image
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 120, height: 80)
                                            .overlay(
                                                Image(systemName: "doc.text.image")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                }
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                
                                // Title and date
                                Text(scan.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                                
                                Text(scan.dateFormatted)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
    }
}

// Scale button style for interactive feedback
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
