import SwiftUI
import AVFoundation
import UIKit


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
    @EnvironmentObject private var onboardingManager: OnboardingManager
    @State private var showingScanner = false
    @State private var showingResults = false
    @State private var hasPermission = false
    @State private var animateScanning = false
    @State private var offsetY: CGFloat = 50
    @State private var opacity: Double = 0
    @State private var showingScanningGuidelines = false

    // Animation properties
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var showMotionGraphics = false

    // State to force refresh of recent scans
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Clean white background
                Color(.systemBackground)
                    .ignoresSafeArea()

                // Content VStack - no maxHeight
                VStack(spacing: 0) {
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        mainCameraView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowCamera"))) { _ in
                // Directly launch the camera when notification is received
                showingScanner = true
            }
            .navigationDestination(isPresented: $showingResults) {
                if let currentScan = viewModel.currentScan {
                    SummaryView(scan: currentScan)
                }
            }
            .onChange(of: viewModel.currentScan) { newScan in
                // Immediately navigate when a new scan is available
                if newScan != nil {
                    showingResults = true
                    // Show history hint after completing a scan
                    onboardingManager.showHistoryHintIfNeeded()

                    // Force refresh of recent scans
                    refreshID = UUID()

                    // Provide success haptic feedback
                    HapticManager.shared.success()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                // Main header content - left-aligned, dark on white
                VStack(alignment: .leading, spacing: 2) {
                    Text("PosterLens")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)

                    Text("Your AI Scientific Conference Companion")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
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
            .sheet(isPresented: $showingScanningGuidelines) {
                ScanningGuidelinesView()
            }
        }
    }
    
    // Loading View with animated elements - responsive to orientation
    private var loadingView: some View {
        Group {
            // Detect orientation using UIDevice instead of GeometryReader
            if UIDevice.current.orientation.isLandscape {
                // Landscape layout - use horizontal arrangement
                HStack(spacing: 30) {
                    // Left side - loading animation
                    ZStack {
                        // Pulsing circle background
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .scaleEffect(pulseScale)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    pulseScale = 1.2
                                }
                            }
                        
                        // Rotating ring
                        Circle()
                            .trim(from: 0, to: 0.8)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(Angle(degrees: rotationAngle))
                            .onAppear {
                                withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    rotationAngle = 360
                                }
                            }
                        
                        // Processing icon
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                    
                    // Right side - text
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Analyzing Poster")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        
                        Text("Extracting insights from your scientific poster...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.trailing)
                }
                .padding(.horizontal, 40)
            } else {
                // Portrait layout - use vertical arrangement
                VStack(spacing: 30) {
                    // Add extra spacing at the top to avoid overlap with header
                    Spacer().frame(height: 60)
                    
                    Text("Analyzing Poster")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    ZStack {
                        // Pulsing circle background
                        Circle()
                            .fill(Color.white.opacity(0.2))
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
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
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
                            .foregroundColor(.white)
                    }
                    
                    Text("Extracting insights from your scientific poster...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding()
            }
        }
    }
    
    // Main Camera View
    private var mainCameraView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                if isLandscape {
                    // Landscape layout - horizontal arrangement
                    HStack(spacing: 20) {
                        // Left side - camera card
                        cameraScanCard
                            .frame(width: geometry.size.width * 0.6)
                            .offset(y: offsetY)
                            .opacity(opacity)
                        
                        // Right side - recent scans
                        if !dataStore.savedScans.isEmpty {
                            VStack {
                                Spacer()
                                recentScansPreview(isLandscape: true)
                                    .frame(width: geometry.size.width * 0.35)
                                    .offset(y: offsetY)
                                    .opacity(opacity)
                                    .id(refreshID) // Force refresh when this ID changes
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // Portrait layout - top-aligned, scrollable
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            scanningGuidelinesPill

                            cameraScanCard

                            if !dataStore.savedScans.isEmpty {
                                recentScansPreview(isLandscape: false)
                                    .id(refreshID) // Force refresh when this ID changes
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .offset(y: offsetY)
                        .opacity(opacity)
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
                        .padding(.bottom, isLandscape ? 40 : 160)
                        .transition(.opacity)
                        .animation(.easeInOut, value: onboardingManager.showCameraHint)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            ZStack {
                // Permission hint removed
                
                CameraPreviewViewControllerRepresentable(
                    onImageCaptured: { image in
                        // Pass permission status to the view model
                        viewModel.processImage(image, hasPermission: hasPermission)
                        showingScanner = false

                        // Navigation is now handled by onChange(of: viewModel.currentScan)
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
                            gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.15)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(height: 40)
                }
                .ignoresSafeArea()
            }
        }
    }
    
    // Full-width Scanning Guidelines pill
    private var scanningGuidelinesPill: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            showingScanningGuidelines = true
        }) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text("Scanning Guidelines")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Compact blue scan card with an "Open camera" button
    private var cameraScanCard: some View {
        Button(action: {
            HapticManager.shared.mediumImpact()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showMotionGraphics = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showingScanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showMotionGraphics = false
                }
            }
        }) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(DesignSystem.Colors.brandGradient)
                    .shadow(color: DesignSystem.Colors.brandBlue.opacity(0.3), radius: 12, x: 0, y: 6)

                // Decorative camera glyph
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.white.opacity(0.12))
                    .padding(20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("CAPTURE")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.7))

                    Text("Scan Scientific Poster")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Point your camera at a research poster to capture, analyze, and get instant insights.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Open camera")
                            .font(.headline)
                    }
                    .foregroundColor(DesignSystem.Colors.brandBlue)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 22)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
                    .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scaleEffect(showMotionGraphics ? 0.97 : 1.0)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Scan scientific poster")
    }
    
    // Recent scans preview section - responsive to orientation
    @ViewBuilder
    private func recentScansPreview(isLandscape: Bool) -> some View {
        if isLandscape {
            landscapeRecentScans
        } else {
            portraitRecentScans
        }
    }

    // Section header with "See all" jumping to the History tab
    private var recentSectionHeader: some View {
        HStack {
            Text("Recent Scans")
                .font(.title3.bold())
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                HapticManager.shared.mediumImpact()
                NotificationCenter.default.post(name: NSNotification.Name("ShowHistory"), object: nil)
            }) {
                HStack(spacing: 2) {
                    Text("See all")
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.brandBlue)
            }
        }
    }

    // Portrait: stack of horizontal cards (padding handled by parent)
    private var portraitRecentScans: some View {
        VStack(alignment: .leading, spacing: 12) {
            recentSectionHeader

            VStack(spacing: 12) {
                ForEach(dataStore.savedScans.sorted(by: { $0.date > $1.date }).prefix(3)) { scan in
                    ScanCardView(scan: scan, isHorizontal: true)
                }
            }
        }
    }

    // Landscape: grid layout sized to available width
    private var landscapeRecentScans: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                recentSectionHeader
                    .padding(.horizontal, 24)

                let recentScans = dataStore.savedScans.sorted(by: { $0.date > $1.date }).prefix(4)
                let itemSize = min(geometry.size.width / 2.2, 160)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: itemSize), spacing: 10)], spacing: 10) {
                    ForEach(Array(recentScans.enumerated()), id: \.element.id) { index, scan in
                        NavigationLink(destination: SummaryView(scan: scan)) {
                            LandscapeScanPreviewItem(scan: scan, width: itemSize)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // Item for landscape mode scan preview grid
    private struct LandscapeScanPreviewItem: View {
        let scan: PosterScan
        let width: CGFloat
        @EnvironmentObject private var dataStore: DataStore
        @State private var showingActionSheet = false
        @State private var showingShareSheet = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                // Thumbnail or placeholder in a sized container
                ZStack {
                    if let image = scan.image {
                        // Check image orientation
                        let isLandscape = image.size.width > image.size.height
                        let height = width * 0.66 // Maintain 3:2 aspect ratio
                        
                        if isLandscape {
                            // For landscape images, we'll center them and maintain aspect ratio
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit() // Maintain aspect ratio without filling
                                    .frame(width: width) // Use passed width
                                    .frame(height: height, alignment: .center) // Center in fixed height container
                                
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
                                .frame(width: width, height: height)
                                .clipped() // Clip the image to prevent overflow
                        }
                    } else {
                        // Placeholder for missing image
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: width, height: width * 0.66)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                }
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                
                // Title and date - constrained to width
                Text(scan.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .frame(width: width, alignment: .leading)
                
                Text(scan.dateFormatted)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
            .padding(.vertical, 4)
            .contextMenu {
                // Context menu for long press
                Button(action: {
                    showingShareSheet = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive, action: {
                    HapticManager.shared.warning()
                    showingActionSheet = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .confirmationDialog("Delete Scan", isPresented: $showingActionSheet, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    HapticManager.shared.success()
                    dataStore.deleteScan(withID: scan.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this scan? This action cannot be undone.")
            }
            .sheet(isPresented: $showingShareSheet) {
                Group {
                    if let image = scan.image {
                        // Share both the image and a text summary
                        let textToShare = "Poster: \(scan.title)\n\nSummary:\n" + scan.summaryPoints.joined(separator: "\n\n")
                        CustomShareSheet(items: [image, textToShare])
                    } else {
                        // Share just the text if no image
                        let textToShare = "Poster: \(scan.title)\n\nSummary:\n" + scan.summaryPoints.joined(separator: "\n\n")
                        CustomShareSheet(items: [textToShare])
                    }
                }
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