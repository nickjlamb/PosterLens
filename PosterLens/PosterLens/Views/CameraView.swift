import SwiftUI
import AVFoundation

struct CameraView: View {
    @EnvironmentObject private var dataStore: DataStore
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showingScanner = false
    @State private var showingResults = false
    @State private var hasPermission = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Processing...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                } else {
                    ZStack(alignment: .bottom) {
                        Button(action: {
                            showingScanner = true
                            // Show permission hint when camera is activated
                            onboardingManager.showPermissionHintIfNeeded()
                        }) {
                            VStack {
                                Image(systemName: "camera")
                                    .font(.system(size: 56))
                                    .padding()
                                
                                Text("Tap here to scan a scientific poster")
                                    .font(.headline)
                                
                                Text("Point camera at poster to capture and summarize")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding()
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
                                .padding(.bottom, 100)
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
                                    showingResults = true
                                    // Show history hint after completing a scan
                                    onboardingManager.showHistoryHintIfNeeded()
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
                            .edgesIgnoringSafeArea(.all)
                            
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
                            .edgesIgnoringSafeArea(.bottom)
                        }
                    }
                    .navigationDestination(isPresented: $showingResults) {
                        if let currentScan = viewModel.currentScan {
                            SummaryView(scan: currentScan)
                        } else {
                            Text("Error processing scan")
                        }
                    }
                }
            }
            .navigationTitle("PosterLens")
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

// SwiftUI wrapper for UIKit-based camera controller
struct CameraPreviewViewControllerRepresentable: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    var onCancel: (() -> Void)? = nil
    @Binding var hasPermission: Bool
    
    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let controller = CameraPreviewViewController()
        controller.onImageCaptured = onImageCaptured
        controller.delegate = context.coordinator
        controller.hasPermission = hasPermission
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {
        // Update permission state when it changes
        uiViewController.hasPermission = hasPermission
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraPreviewViewControllerDelegate {
        var parent: CameraPreviewViewControllerRepresentable
        
        init(_ parent: CameraPreviewViewControllerRepresentable) {
            self.parent = parent
        }
        
        func cameraPreviewViewControllerDidCancel(_ controller: CameraPreviewViewController) {
            parent.onCancel?()
        }
        
        func cameraPreviewViewControllerDidTogglePermission(_ controller: CameraPreviewViewController, hasPermission: Bool) {
            parent.hasPermission = hasPermission
        }
    }
}
