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
    @State private var showingAboutView = false
    @State private var showingScanningGuidelines = false

    // Animation properties
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var showMotionGraphics = false

    // State to force refresh of recent scans
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                // Content container with proper framing
                VStack {
                    // Exact same blue gradient as in AboutView
                    ZStack {
                        DesignSystem.Colors.brandGradient
                            .ignoresSafeArea()

                        // Very subtle background circles (less prominent than in AboutView)
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 200, height: 200)
                            .blur(radius: 30)
                            .offset(x: -150, y: 50)

                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 300, height: 300)
                            .blur(radius: 40)
                            .offset(x: 150, y: 400)
                    }

                    if viewModel.isLoading {
                        loadingView
                    } else {
                        mainCameraView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Top-right info button - direct child of ZStack
                Button(action: {
                    showingAboutView = true
                }) {
                    Image(systemName: "info.circle")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                        .padding()
                }
                .buttonPressAnimation()
                .padding(.top, 50)
                .padding(.trailing, 20)
                .zIndex(1)
            }
            .ignoresSafeArea()
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
                Group {
                    if UIDevice.current.orientation.isLandscape {
                        // Landscape header - use HStack and position to the left
                        HStack(spacing: 8) {
                            Spacer().frame(width: 16)
                            
                            Text("PosterLens")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            
                            Text("Your AI Scientific Conference Companion")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.leading, 4)
                            
                            Spacer()
                        }
                        .frame(height: 44)
                    } else {
                        // Portrait header - use traditional VStack centered
                        VStack(spacing: 4) {
                            Text("PosterLens")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("Your AI Scientific Conference Companion")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 5)
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
            .sheet(isPresented: $showingAboutView) {
                AboutView()
                    .environmentObject(onboardingManager)
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
                                recentScansPreview
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
                    // Portrait layout - vertical arrangement
                    VStack {
                        Spacer()

                        // Camera button section with cards
                        cameraScanCard
                            .offset(y: offsetY)
                            .opacity(opacity)

                        // Scanning Guidelines button
                        Button(action: {
                            showingScanningGuidelines = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 16))
                                Text("Scanning Guidelines")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(25)
                        }
                        .buttonPressAnimation()
                        .padding(.top, 16)
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
    
    // Camera scan card with animations - responsive to orientation
    private var cameraScanCard: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            Button(action: {
                // Add haptic feedback
                HapticManager.shared.mediumImpact()
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showMotionGraphics = true
                }
                
                // Delayed action to allow animation to run
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingScanner = true
                    
                    // Reset animation state for next use
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showMotionGraphics = false
                    }
                }
            }) {
                ZStack {
                    // Card background with shadow
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                        .scaleEffect(showMotionGraphics ? 0.96 : 1.0)
                    
                    if isLandscape {
                        // Landscape layout - horizontal arrangement
                        HStack(spacing: 20) {
                            // Left side - icon
                            ZStack {
                                // Background circle with gradient
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [DesignSystem.Colors.brandBlue, DesignSystem.Colors.brandBlueDark.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 90, height: 90)
                                    .scaleEffect(showMotionGraphics ? 1.1 : 1.0)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                // Camera icon
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 38, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 30)
                            
                            // Right side - text and button
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Scan Scientific Poster")
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)
                                
                                Text("Point your camera at a research poster to capture, analyze, and get instant insights")
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                    .fontWeight(.medium)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.trailing, 10)
                                
                                // Scan button
                                Text("Tap to Scan")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 30)
                                    .background(LinearGradient(
                                        colors: [DesignSystem.Colors.brandBlue, DesignSystem.Colors.brandBlueDark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .cornerRadius(30)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            .padding(.vertical)
                            .padding(.horizontal, 20)
                            .padding(.trailing, 10)
                        }
                    } else {
                        // Portrait layout - vertical arrangement
                        VStack(spacing: 24) {
                            // Animated camera icon
                            ZStack {
                                // Background circle with gradient
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [DesignSystem.Colors.brandBlue, DesignSystem.Colors.brandBlueDark.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
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
                                
                                Text("Point your camera at a research poster\nto capture,\nanalyze, and get instant insights")
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Scan button
                            Text("Tap to Scan")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 40)
                                .background(LinearGradient(
                                    colors: [DesignSystem.Colors.brandBlue, DesignSystem.Colors.brandBlueDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .cornerRadius(30)
                                .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .padding(.vertical, 32)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(height: UIDevice.current.orientation.isLandscape ? 180 : 360)
        .padding(.horizontal, 24)
        .accessibilityLabel("Scan scientific poster")
    }
    
    // Recent scans preview section - responsive to orientation
    private var recentScansPreview: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Scans")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                
                if isLandscape {
                    // In landscape mode, show a grid layout
                    VStack {
                        // Use sorted array to ensure most recent scans appear first
                        let recentScans = dataStore.savedScans.sorted(by: { $0.date > $1.date }).prefix(4)
                        
                        // Calculate sizes based on available space
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
                } else {
                    // In portrait mode, use horizontal scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            // Use sorted array to ensure most recent scans appear first
                            ForEach(Array(dataStore.savedScans.sorted(by: { $0.date > $1.date }).prefix(5).enumerated()), id: \.element.id) { index, scan in
                                NavigationLink(destination: SummaryView(scan: scan)) {
                                    PortraitScanPreviewItem(scan: scan)
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
    }
    
    // Item for portrait mode scan preview
    private struct PortraitScanPreviewItem: View {
        let scan: PosterScan
        @EnvironmentObject private var dataStore: DataStore
        @State private var showingActionSheet = false
        @State private var showingShareSheet = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                // Thumbnail or placeholder in a fixed size container
                ZStack {
                    if let image = scan.image {
                        // Check image orientation
                        let isLandscape = image.size.width > image.size.height
                        
                        if isLandscape {
                            // For landscape images, we'll center them and maintain aspect ratio
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
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 120, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                }
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                
                // Title and date
                Text(scan.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .frame(width: 120, alignment: .leading)
                
                Text(scan.dateFormatted)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
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