import UIKit
import AVFoundation

protocol CameraPreviewViewControllerDelegate: AnyObject {
    func cameraPreviewViewControllerDidCancel(_ controller: CameraPreviewViewController)
    func cameraPreviewViewControllerDidTogglePermission(_ controller: CameraPreviewViewController, hasPermission: Bool)
}

class CameraPreviewViewController: UIViewController {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let photoOutput = AVCapturePhotoOutput()
    
    var onImageCaptured: ((UIImage) -> Void)?
    
    weak var delegate: CameraPreviewViewControllerDelegate?
    
    private var captureButton: UIButton!
    private var cancelButton: UIButton!
    private var flashButton: UIButton!
    private var gridButton: UIButton!
    private var isGridVisible = false
    private var gridView: UIView?
    
    // Simulator detection
    private var isSimulator: Bool {
        get {
            #if targetEnvironment(simulator)
            return true
            #else
            return _isSimulatedEnvironment
            #endif
        }
    }
    
    // Use this flag to simulate the simulator environment in cases where camera fails
    private var _isSimulatedEnvironment: Bool = false
    
    // Always allow capture
    var hasPermission: Bool = true
    
    // Flags to track camera state
    private var isCameraBeingSetup = false
    private var isCameraReady = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("CameraPreviewViewController viewDidLoad")
        
        if isSimulator {
            print("Running in simulator - creating mock camera interface")
            setupSimulatorUI()
        } else {
            // First set up the UI with placeholders
            setupUI()
            
            // Then initialize camera in the background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                // Set flag to prevent concurrent initialization
                self.isCameraBeingSetup = true
                
                // Setup the capture session
                self.setupCaptureSession()
                
                // Clear the flag after a brief delay to ensure everything settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    print("Camera setup completed - clearing setup flag")
                    self.isCameraBeingSetup = false
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Skip camera-specific layout if in simulator
        if isSimulator {
            return
        }
        
        // Add safety check for previewLayer
        guard let previewLayer = self.previewLayer else {
            print("Warning: Cannot update layout - preview layer is nil")
            return
        }
        
        // Update preview layer frame with proper animation
        CATransaction.begin()
        CATransaction.setDisableActions(false) // Enable implicit animations
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        // Update the preview layer's frame
        previewLayer.frame = view.bounds
        
        CATransaction.commit()
        
        // Update orientation and grid without animation (handled separately)
        updatePreviewLayerVideoOrientation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print("viewWillAppear called")
        
        // Start observing device orientation changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
                                               
        // Enable device orientation notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Skip camera operations if in simulator
        if isSimulator {
            // Mock camera is always ready
            isCameraReady = true
            return
        }
        
        // Set initial orientation
        updatePreviewLayerVideoOrientation()
        
        // Try to determine the state of the camera
        if let captureSession = self.captureSession {
            if captureSession.isRunning {
                print("Capture session already running, marking camera as ready")
                self.isCameraReady = true
            } else if !isCameraBeingSetup {
                print("Starting capture session from viewWillAppear because it exists but isn't running")
                // Start the session directly
                DispatchQueue.global(qos: .userInitiated).async {
                    captureSession.startRunning()
                    print("Capture session started from viewWillAppear")
                    
                    // Mark as ready after the session has started
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self = self else { return }
                        print("Camera is now marked as ready from viewWillAppear")
                        self.isCameraReady = true
                    }
                }
            } else {
                print("Camera is being set up, regular startup will be used")
                // Regular startup is being handled by setup process
            }
        } else {
            print("No capture session available in viewWillAppear, waiting for setup to complete")
            // The session is being created, we need to wait
        }
        
        // Schedule a check to see if camera is ready after a few seconds
        // This ensures we don't get stuck in non-ready state
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, !self.isCameraReady, !self.isSimulator else { return }
            
            print("Camera readiness timeout - forcing ready state")
            
            // At this point, we need to check one more time if the session exists and is running
            if let captureSession = self.captureSession {
                if !captureSession.isRunning && !self.isCameraBeingSetup {
                    print("Trying to start session one last time after timeout")
                    DispatchQueue.global(qos: .userInitiated).async {
                        captureSession.startRunning()
                        print("Last attempt to start capture session successful")
                    }
                }
            }
            
            // Force ready state to prevent permanent failure
            self.isCameraReady = true
        }
    }
    
    private func startCaptureSessionIfNeeded() {
        // Don't start the session if it's currently being set up
        if isCameraBeingSetup {
            print("Camera is currently being initialized, skipping startRunning call")
            return
        }
        
        // Start capture session - add nil check
        guard let captureSession = self.captureSession else {
            print("Warning: Cannot start capture session - session is nil")
            return
        }
        
        // Ensure we're not in the middle of a configuration when starting the session
        if captureSession.isRunning == false {
            // Log that we're starting the capture session
            print("Starting capture session...")
            
            // Set camera as not ready until fully running
            self.isCameraReady = false
            
            // Use a dedicated background queue for camera operations
            DispatchQueue.global(qos: .userInitiated).async {
                // Important: Make sure we're not in the middle of configuration
                // when calling startRunning
                captureSession.startRunning()
                print("Capture session started successfully")
                
                // Update UI on main thread if needed
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // If the previewLayer exists but hasn't been added to view yet, add it now
                    if let previewLayer = self.previewLayer, let backgroundView = self.view.viewWithTag(1001) {
                        if previewLayer.superlayer == nil {
                            print("Adding previously initialized previewLayer to view")
                            previewLayer.frame = self.view.bounds
                            backgroundView.layer.addSublayer(previewLayer)
                        }
                    }
                    
                    self.updatePreviewLayerVideoOrientation()
                    
                    // Mark camera as ready after a short delay to ensure everything is settled
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("Camera is now marked as ready")
                        self.isCameraReady = true
                    }
                }
            }
        } else {
            // If already running, it's ready
            if !isCameraReady {
                print("Camera session already running, marking as ready")
                self.isCameraReady = true
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        print("viewWillDisappear called")
        
        // Mark camera as not ready when view disappears
        isCameraReady = false
        
        // Stop observing orientation changes
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        
        // Clean up any grid view if visible
        if isGridVisible {
            isGridVisible = false
            gridView?.removeFromSuperview()
            gridView = nil
        }
        
        // Cancel any pending alert presentations
        isAlertPresented = false
        
        // Skip camera operations if in simulator
        if isSimulator {
            return
        }
        
        // Don't stop the session if it's currently being set up
        if isCameraBeingSetup {
            print("Camera is being initialized, skipping stopRunning call")
            return
        }
        
        // Add nil check for captureSession
        if let captureSession = self.captureSession, captureSession.isRunning {
            // Stop session on background thread to avoid UI blocking
            print("Stopping capture session")
            DispatchQueue.global(qos: .userInteractive).async {
                captureSession.stopRunning()
                print("Capture session stopped successfully")
            }
        }
    }
    
    // Handle device rotation via view controller lifecycle method (modern approach)
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Use the transition coordinator to animate along with the rotation
        coordinator.animate(alongsideTransition: { [weak self] _ in
            // Update orientation during the system animation
            self?.updatePreviewLayerVideoOrientation()
        }, completion: { [weak self] _ in
            // Ensure we've fully updated after the transition completes
            self?.updateUIForCurrentOrientation()
        })
    }
    
    @objc private func deviceOrientationDidChange() {
        // Check if the view controller is still in the view hierarchy
        // This prevents crashes when orientation changes while the view controller is being dismissed
        guard self.view.window != nil else {
            print("Warning: Orientation changed but view is not in window hierarchy")
            return
        }
        
        // Use a slight delay to ensure animation happens after the device has fully rotated
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check if previewLayer exists before updating orientation
            guard self.previewLayer != nil else {
                print("Warning: Cannot update orientation - preview layer is nil")
                return
            }
            
            self.updatePreviewLayerVideoOrientation()
        }
    }
    
    private func updatePreviewLayerVideoOrientation() {
        // Ensure this method runs on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updatePreviewLayerVideoOrientation()
            }
            return
        }
        
        // Add safety check for previewLayer
        guard let previewLayer = self.previewLayer else {
            print("Warning: Cannot update orientation - preview layer is nil")
            return
        }
        
        guard let connection = previewLayer.connection else { return }
        
        // First check the interface orientation which is more stable during transitions
        let videoOrientation: AVCaptureVideoOrientation
        
        // Get the current interface orientation first (more reliable for UI)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let interfaceOrientation = windowScene.interfaceOrientation
            
            switch interfaceOrientation {
            case .portrait:
                videoOrientation = .portrait
            case .portraitUpsideDown:
                videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                videoOrientation = .landscapeLeft
            case .landscapeRight:
                videoOrientation = .landscapeRight
            case .unknown:
                // Fall back to device orientation if interface orientation is unknown
                let deviceOrientation = UIDevice.current.orientation
                
                switch deviceOrientation {
                case .portrait:
                    videoOrientation = .portrait
                case .portraitUpsideDown:
                    videoOrientation = .portraitUpsideDown
                case .landscapeLeft:
                    // Note: landscapeLeft for the device is landscapeRight for the camera
                    videoOrientation = .landscapeRight
                case .landscapeRight:
                    // Note: landscapeRight for the device is landscapeLeft for the camera
                    videoOrientation = .landscapeLeft
                default:
                    videoOrientation = .portrait // Default to portrait for face up/down
                }
            @unknown default:
                videoOrientation = .portrait
            }
        } else {
            // If no window scene, fall back to device orientation
            let deviceOrientation = UIDevice.current.orientation
            
            switch deviceOrientation {
            case .portrait:
                videoOrientation = .portrait
            case .portraitUpsideDown:
                videoOrientation = .portraitUpsideDown
            case .landscapeLeft:
                videoOrientation = .landscapeRight
            case .landscapeRight:
                videoOrientation = .landscapeLeft
            default:
                videoOrientation = .portrait
            }
        }
        
        // Only change orientation if it actually changed to avoid unnecessary animations
        if connection.isVideoOrientationSupported && connection.videoOrientation != videoOrientation {
            // Set up animation before changing orientation
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3) // Slightly longer for smoother transition
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            CATransaction.setCompletionBlock { [weak self] in
                // Update UI elements after animation completes
                DispatchQueue.main.async {
                    self?.updateUIForCurrentOrientation()
                }
            }
            
            // Update the connection's orientation
            connection.videoOrientation = videoOrientation
            
            // Commit the transaction
            CATransaction.commit()
        }
    }
    
    private func updateUIForCurrentOrientation() {
        // Ensure this method runs on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateUIForCurrentOrientation()
            }
            return
        }
        
        // Add safety check for previewLayer
        guard let previewLayer = self.previewLayer else {
            print("Warning: Cannot update UI for orientation - preview layer is nil")
            return
        }
        
        // First do any critical view updates that need to happen immediately
        previewLayer.frame = view.bounds
        
        // Then animate UI elements for a smoother transition
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            // Update grid view if visible
            if self.isGridVisible {
                self.updateGridView()
            }
            
            // Ensure any overlays or UI elements adapt to the new orientation
            self.layoutCameraControls()
            
            // Force layout immediately to prevent lag
            self.view.layoutIfNeeded()
        })
    }
    
    // Store constraints to be able to activate/deactivate them
    private var portraitConstraints: [NSLayoutConstraint] = []
    private var landscapeConstraints: [NSLayoutConstraint] = []
    
    private func setupOrientationConstraints() {
        // Remove any existing constraints first to prevent conflicts
        if !portraitConstraints.isEmpty {
            NSLayoutConstraint.deactivate(portraitConstraints)
        }
        if !landscapeConstraints.isEmpty {
            NSLayoutConstraint.deactivate(landscapeConstraints)
        }
        
        // Create portrait constraints (bottom center)
        portraitConstraints = [
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ]
        
        // Create landscape constraints (right side center)
        landscapeConstraints = [
            captureButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            captureButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ]
        
        // Set a higher priority to ensure constraints don't conflict
        for constraint in portraitConstraints + landscapeConstraints {
            constraint.priority = .defaultHigh
        }
        
        // Get the current device orientation
        let currentOrientation = UIDevice.current.orientation
        
        // Activate the appropriate constraints based on current orientation
        if currentOrientation.isLandscape {
            NSLayoutConstraint.activate(landscapeConstraints)
        } else {
            NSLayoutConstraint.activate(portraitConstraints)
        }
    }
    
    private func layoutCameraControls() {
        // First try to get the interface orientation
        var isLandscape = false
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            isLandscape = windowScene.interfaceOrientation.isLandscape
        } else {
            // Fall back to device orientation if interface orientation is not available
            let deviceOrientation = UIDevice.current.orientation
            // Only modify layout for valid orientations
            guard deviceOrientation.isValidInterfaceOrientation else { return }
            isLandscape = deviceOrientation.isLandscape
        }
        
        // Only adjust controls if our constraints are initialized
        if !portraitConstraints.isEmpty && !landscapeConstraints.isEmpty {
            // Use UIView animation to batch constraint changes
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
                if isLandscape {
                    // Switch to landscape layout
                    NSLayoutConstraint.deactivate(self.portraitConstraints)
                    NSLayoutConstraint.activate(self.landscapeConstraints)
                    
                    // Add some visual weight to the capture button in landscape
                    self.captureButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                } else {
                    // Switch to portrait layout
                    NSLayoutConstraint.deactivate(self.landscapeConstraints)
                    NSLayoutConstraint.activate(self.portraitConstraints)
                    
                    // Reset transform in portrait
                    self.captureButton.transform = CGAffineTransform.identity
                }
                
                // Force layout immediately within the animation block
                self.view.layoutIfNeeded()
            })
        }
    }
    
    private func setupCaptureSession() {
        do {
            print("Setting up camera capture session...")
            captureSession = AVCaptureSession()
            
            // Configure the session for high resolution capture
            if #available(iOS 16.0, *) {
                // Begin configuration
                captureSession.beginConfiguration()
                
                do {
                    // Set up the capture device
                    guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        throw NSError(domain: "CameraSetupError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access camera device"])
                    }
                    
                    print("Found camera device: \(videoDevice.localizedName)")
                    
                    // Create input
                    let videoDeviceInput: AVCaptureDeviceInput
                    do {
                        videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                        print("Created video device input")
                    } catch {
                        throw NSError(domain: "CameraSetupError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create input device: \(error.localizedDescription)"])
                    }
                    
                    // Add input
                    guard captureSession.canAddInput(videoDeviceInput) else {
                        throw NSError(domain: "CameraSetupError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input to session"])
                    }
                    
                    print("Adding video input to session")
                    captureSession.addInput(videoDeviceInput)
                    
                    // Set up photo output
                    guard captureSession.canAddOutput(photoOutput) else {
                        throw NSError(domain: "CameraSetupError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot add photo output to session"])
                    }
                    
                    print("Adding photo output to session")
                    captureSession.addOutput(photoOutput)
                    
                    // Configure photo output
                    let format = videoDevice.activeFormat
                    if let dimensions = format.supportedMaxPhotoDimensions.first {
                        print("Setting max photo dimensions: \(dimensions)")
                        photoOutput.maxPhotoDimensions = dimensions
                    } else {
                        print("No supported max photo dimensions found")
                    }
                    
                    photoOutput.isLivePhotoCaptureEnabled = false
                    print("Live photo capture disabled")
                } catch {
                    // If anything fails, commit the configuration to avoid hanging in configuration state
                    print("Error during configuration: \(error.localizedDescription)")
                    captureSession.commitConfiguration()
                    throw error
                }
                
                // Finalize configuration
                print("Committing capture session configuration")
                captureSession.commitConfiguration()
            } else {
                // Fallback for earlier iOS versions
                captureSession.beginConfiguration()
                
                do {
                    guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                        throw NSError(domain: "CameraSetupError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access camera device"])
                    }
                    
                    print("Found camera device: \(videoDevice.localizedName)")
                    
                    let videoDeviceInput: AVCaptureDeviceInput
                    do {
                        videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                        print("Created video device input")
                    } catch {
                        throw NSError(domain: "CameraSetupError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create input device: \(error.localizedDescription)"])
                    }
                    
                    guard captureSession.canAddInput(videoDeviceInput) else {
                        throw NSError(domain: "CameraSetupError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input to session"])
                    }
                    
                    print("Adding video input to session")
                    captureSession.addInput(videoDeviceInput)
                    
                    guard captureSession.canAddOutput(photoOutput) else {
                        throw NSError(domain: "CameraSetupError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot add photo output to session"])
                    }
                    
                    print("Adding photo output to session")
                    captureSession.addOutput(photoOutput)
                    photoOutput.isHighResolutionCaptureEnabled = true
                    photoOutput.isLivePhotoCaptureEnabled = false
                    print("High-resolution photo capture enabled")
                } catch {
                    // If anything fails, commit the configuration to avoid hanging in configuration state
                    print("Error during configuration: \(error.localizedDescription)")
                    captureSession.commitConfiguration()
                    throw error
                }
                
                // Finalize configuration
                print("Committing capture session configuration")
                captureSession.commitConfiguration()
            }
            
            // Set up the preview layer - only after configuration is committed
            print("Creating preview layer")
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            
            // Only update orientation on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Add preview layer to view if needed
                if let previewLayer = self.previewLayer, let backgroundView = self.view.viewWithTag(1001) {
                    print("Adding preview layer to view hierarchy")
                    previewLayer.frame = self.view.bounds
                    backgroundView.layer.addSublayer(previewLayer)
                }
                
                if self.previewLayer != nil {
                    print("Updating video orientation")
                    self.updatePreviewLayerVideoOrientation()
                }
                
                // Start the session manually instead of using the normal method
                // to avoid timing issues with the isCameraBeingSetup flag
                print("Starting capture session directly from setup method")
                if let captureSession = self.captureSession, !captureSession.isRunning {
                    DispatchQueue.global(qos: .userInitiated).async {
                        captureSession.startRunning()
                        print("Capture session started directly")
                        
                        // Mark as ready after the session has started
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            guard let self = self else { return }
                            print("Camera is now marked as ready from direct start")
                            self.isCameraReady = true
                        }
                    }
                }
            }
            
            print("Camera session setup completed successfully")
            
        } catch {
            print("Camera setup error: \(error.localizedDescription)")
            // Clean up any partially initialized resources
            self.captureSession = nil
            self.previewLayer = nil
            
            // Show error alert on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // In debug mode, simulate a mock camera for testing
                #if DEBUG
                print("DEBUG mode: Setting up mock camera interface after error")
                self._isSimulatedEnvironment = true
                self.setupSimulatorUI()
                #else
                self.presentCameraSetupErrorAlert()
                #endif
            }
        }
    }
    
    private func setupUI() {
        // Set up a camera background view regardless of previewLayer status
        let cameraBackgroundView = UIView(frame: view.bounds)
        cameraBackgroundView.backgroundColor = .black
        cameraBackgroundView.tag = 1001 // Tag for future reference
        view.addSubview(cameraBackgroundView)
        
        // Only add the preview layer if it's already initialized
        if let previewLayer = self.previewLayer {
            print("Adding preview layer to view")
            previewLayer.frame = view.bounds
            cameraBackgroundView.layer.addSublayer(previewLayer)
        } else {
            print("Preview layer not yet initialized, will add later")
            // Don't show error - previewLayer will be set up asynchronously
        }
        
        // Create capture button
        captureButton = UIButton(type: .system)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
        captureButton.tintColor = .white
        captureButton.contentVerticalAlignment = .fill
        captureButton.contentHorizontalAlignment = .fill
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        captureButton.alpha = 1.0 // Permission check removed - button always enabled
        
        // Create cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        // Create flash button
        flashButton = UIButton(type: .system)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        
        // Create grid button
        gridButton = UIButton(type: .system)
        gridButton.translatesAutoresizingMaskIntoConstraints = false
        gridButton.setImage(UIImage(systemName: "grid"), for: .normal)
        gridButton.tintColor = .white
        gridButton.addTarget(self, action: #selector(toggleGrid), for: .touchUpInside)
        
        // Permission UI removed - always allow capture
        
        // Add buttons to view
        view.addSubview(captureButton)
        view.addSubview(cancelButton)
        view.addSubview(flashButton)
        view.addSubview(gridButton)
        
        // Set up size constraints for buttons
        NSLayoutConstraint.activate([
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80),
            
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flashButton.widthAnchor.constraint(equalToConstant: 44),
            flashButton.heightAnchor.constraint(equalToConstant: 44),
            
            gridButton.topAnchor.constraint(equalTo: flashButton.bottomAnchor, constant: 20),
            gridButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            gridButton.widthAnchor.constraint(equalToConstant: 44),
            gridButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Set up orientation-specific constraints for the capture button
        setupOrientationConstraints()
        
        // Add tap gesture recognizer for focus
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func capturePhoto() {
        // If running in simulator, use mock photo
        if isSimulator {
            mockCapturePhoto()
            return
        }
        
        // Check if camera is still being initialized
        if isCameraBeingSetup {
            print("Camera is still being set up, cannot capture photo yet")
            presentCameraSetupErrorAlert()
            return
        }
        
        // Check if camera is ready for capture
        if !isCameraReady {
            print("Camera is not yet ready for capture, using mock photo")
            #if DEBUG
            mockCapturePhoto()
            #else
            presentCameraSetupErrorAlert()
            #endif
            return
        }
        
        // Check for nil captureSession and it must be running
        guard let captureSession = self.captureSession else {
            print("Error: Cannot capture photo - capture session is nil")
            #if DEBUG
            mockCapturePhoto()
            #else
            presentCameraSetupErrorAlert()
            #endif
            return
        }
        
        // If the session exists but isn't running, try to start it
        if !captureSession.isRunning {
            print("Capture session exists but isn't running, trying to start it")
            
            // Try to start the session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                print("Started capture session during photo capture attempt")
            }
            
            // Use mock photo in the meantime
            print("Using mock photo while session starts")
            mockCapturePhoto()
            return
        }
        
        guard let photoOutput = self.photoOutput as AVCapturePhotoOutput? else {
            print("Error: Cannot capture photo - photo output is nil")
            #if DEBUG
            mockCapturePhoto()
            #else
            presentCameraSetupErrorAlert()
            #endif
            return
        }
        
        // Check for nil previewLayer
        guard let previewLayer = self.previewLayer else {
            print("Error: Cannot capture photo - preview layer is nil")
            #if DEBUG
            mockCapturePhoto()
            #else
            presentCameraSetupErrorAlert()
            #endif
            return
        }
        
        // Verify output is connected to session
        guard photoOutput.connections.contains(where: { $0.isEnabled }) else {
            print("Error: photoOutput is not enabled or not connected to the session")
            #if DEBUG
            mockCapturePhoto()
            #else
            presentCameraSetupErrorAlert()
            #endif
            return
        }
        
        // Animate the capture button
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = CGAffineTransform.identity
            }
        }
        
        print("Preparing to capture photo...")
        
        // Configure photo settings
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        
        // Enable flash if available
        if let device = AVCaptureDevice.default(for: .video),
           device.hasFlash {
            settings.flashMode = device.isTorchActive ? .on : .off
        }
        
        // Ensure the connection's video orientation is updated before capture
        if let photoOutputConnection = photoOutput.connection(with: .video) {
            if let previewConnection = previewLayer.connection, photoOutputConnection.isVideoOrientationSupported {
                photoOutputConnection.videoOrientation = previewConnection.videoOrientation
            }
        }
        
        // Capture the photo
        print("Capturing photo...")
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // Handle permission toggle changes
    // Permission toggled method removed
    
    // Update capture button state method removed
    
    // Permission required animation method removed
    
    @objc private func cancelButtonTapped() {
        // Notify delegate instead of trying to dismiss directly
        delegate?.cameraPreviewViewControllerDidCancel(self)
    }
    
    @objc private func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if device.isTorchActive {
                device.torchMode = .off
                flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
            } else {
                try device.setTorchModeOn(level: 1.0)
                flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error toggling flash: \(error.localizedDescription)")
        }
    }
    
    @objc private func toggleGrid() {
        isGridVisible.toggle()
        
        if isGridVisible {
            gridButton.tintColor = .systemBlue
        } else {
            gridButton.tintColor = .white
        }
        
        updateGridView()
    }
    
    private func updateGridView() {
        // Check for valid view before updating
        guard view != nil else {
            print("Warning: Cannot update grid view - view is nil")
            return
        }
        
        // Remove existing grid view if any
        gridView?.removeFromSuperview()
        
        // Check if grid should be visible
        if isGridVisible {
            // Create new grid view - createGridView() has its own nil check for previewLayer
            let newGridView = createGridView()
            newGridView.alpha = 0
            view.addSubview(newGridView)
            gridView = newGridView
            
            // Fade in the grid
            UIView.animate(withDuration: 0.2) {
                newGridView.alpha = 1
            }
        }
    }
    
    private func createGridView() -> UIView {
        // Add safety check for previewLayer
        guard let previewLayer = self.previewLayer else {
            print("Warning: Cannot create grid view - preview layer is nil")
            // Return an empty view as fallback
            return UIView(frame: view.bounds)
        }
        
        let gridView = UIView(frame: previewLayer.frame)
        gridView.isUserInteractionEnabled = false
        
        // Add a semi-transparent overlay to make grid more visible
        let overlay = UIView(frame: gridView.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gridView.addSubview(overlay)
        
        // Use constants for more consistent appearance during rotation
        let horizontalSpacing = gridView.frame.height / 3
        let verticalSpacing = gridView.frame.width / 3
        
        // Create horizontal lines
        for i in 1...2 {
            let horizontalLine = UIView()
            horizontalLine.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            horizontalLine.translatesAutoresizingMaskIntoConstraints = false
            gridView.addSubview(horizontalLine)
            
            // Use auto layout for better rotation support
            NSLayoutConstraint.activate([
                horizontalLine.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
                horizontalLine.trailingAnchor.constraint(equalTo: gridView.trailingAnchor),
                horizontalLine.topAnchor.constraint(equalTo: gridView.topAnchor, constant: horizontalSpacing * CGFloat(i)),
                horizontalLine.heightAnchor.constraint(equalToConstant: 1.0)
            ])
        }
        
        // Create vertical lines
        for i in 1...2 {
            let verticalLine = UIView()
            verticalLine.backgroundColor = UIColor.white.withAlphaComponent(0.5)
            verticalLine.translatesAutoresizingMaskIntoConstraints = false
            gridView.addSubview(verticalLine)
            
            // Use auto layout for better rotation support
            NSLayoutConstraint.activate([
                verticalLine.topAnchor.constraint(equalTo: gridView.topAnchor),
                verticalLine.bottomAnchor.constraint(equalTo: gridView.bottomAnchor),
                verticalLine.leadingAnchor.constraint(equalTo: gridView.leadingAnchor, constant: verticalSpacing * CGFloat(i)),
                verticalLine.widthAnchor.constraint(equalToConstant: 1.0)
            ])
        }
        
        return gridView
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: view)
        focusAtPoint(touchPoint)
    }
    
    private func focusAtPoint(_ point: CGPoint) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusModeSupported(.autoFocus) && device.isFocusPointOfInterestSupported {
                let focusPoint = CGPoint(
                    x: point.x / view.bounds.width,
                    y: point.y / view.bounds.height
                )
                
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
                
                // Show focus animation
                showFocusAnimation(at: point)
            }
            
            if device.isExposureModeSupported(.autoExpose) && device.isExposurePointOfInterestSupported {
                let exposurePoint = CGPoint(
                    x: point.x / view.bounds.width,
                    y: point.y / view.bounds.height
                )
                
                device.exposurePointOfInterest = exposurePoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus: \(error.localizedDescription)")
        }
    }
    
    private func showFocusAnimation(at point: CGPoint) {
        // Remove any existing focus views
        view.subviews.forEach { subview in
            if subview.tag == 100 {
                subview.removeFromSuperview()
            }
        }
        
        // Create focus animation view
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        focusView.backgroundColor = UIColor.clear
        focusView.layer.borderColor = UIColor.yellow.cgColor
        focusView.layer.borderWidth = 1.0
        focusView.tag = 100
        view.addSubview(focusView)
        
        // Animate focus view
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            focusView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0.1, options: .curveEaseInOut, animations: {
                focusView.alpha = 0
            }, completion: { _ in
                focusView.removeFromSuperview()
            })
        })
    }
    
    // Set up a simulator-specific UI that doesn't need camera access
    private func setupSimulatorUI() {
        // Create a mock camera view with striped background
        let mockCameraView = UIView(frame: view.bounds)
        mockCameraView.backgroundColor = UIColor.darkGray
        
        // Add a pattern overlay to simulate camera view
        let patternView = UIView(frame: mockCameraView.bounds)
        patternView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        mockCameraView.addSubview(patternView)
        
        // Add information label
        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.text = "Camera not available in Simulator"
        infoLabel.textColor = .white
        infoLabel.textAlignment = .center
        infoLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        mockCameraView.addSubview(infoLabel)
        
        // Add a mock photo button
        let mockButton = UIButton(type: .system)
        mockButton.translatesAutoresizingMaskIntoConstraints = false
        mockButton.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
        mockButton.tintColor = .white
        mockButton.contentVerticalAlignment = .fill
        mockButton.contentHorizontalAlignment = .fill
        mockButton.addTarget(self, action: #selector(mockCapturePhoto), for: .touchUpInside)
        mockCameraView.addSubview(mockButton)
        
        // Create cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        mockCameraView.addSubview(cancelButton)
        
        // Add the mock view to our view hierarchy
        view.addSubview(mockCameraView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            infoLabel.centerXAnchor.constraint(equalTo: mockCameraView.centerXAnchor),
            infoLabel.centerYAnchor.constraint(equalTo: mockCameraView.centerYAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: mockCameraView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: mockCameraView.trailingAnchor, constant: -20),
            
            mockButton.centerXAnchor.constraint(equalTo: mockCameraView.centerXAnchor),
            mockButton.bottomAnchor.constraint(equalTo: mockCameraView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            mockButton.widthAnchor.constraint(equalToConstant: 80),
            mockButton.heightAnchor.constraint(equalToConstant: 80),
            
            cancelButton.topAnchor.constraint(equalTo: mockCameraView.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: mockCameraView.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func mockCapturePhoto() {
        // Create a simple gradient image as a mock photo
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600))
        let mockImage = renderer.image { ctx in
            // Create a gradient background
            let colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemGray.cgColor
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colorLocations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors as CFArray,
                locations: colorLocations
            )!
            
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 1200, y: 1600),
                options: []
            )
            
            // Add some text for demo purposes
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: UIColor.white
            ]
            
            let text = "Sample Poster"
            let textRect = CGRect(x: 400, y: 700, width: 400, height: 200)
            text.draw(with: textRect, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
            
            // Add a few more text elements to simulate a scientific poster
            let smallerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: UIColor.white
            ]
            
            "Abstract".draw(with: CGRect(x: 400, y: 800, width: 400, height: 100), 
                           options: .usesLineFragmentOrigin, 
                           attributes: smallerAttrs, 
                           context: nil)
                           
            "Methods".draw(with: CGRect(x: 400, y: 900, width: 400, height: 100), 
                          options: .usesLineFragmentOrigin, 
                          attributes: smallerAttrs, 
                          context: nil)
                          
            "Results".draw(with: CGRect(x: 400, y: 1000, width: 400, height: 100), 
                          options: .usesLineFragmentOrigin, 
                          attributes: smallerAttrs, 
                          context: nil)
        }
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Call the completion handler on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onImageCaptured?(mockImage)
        }
    }
    
    // Track if an alert is already being presented to prevent multiple alerts
    private var isAlertPresented = false
    
    private func presentCameraSetupErrorAlert() {
        // Only present one alert at a time
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isAlertPresented {
                print("Alert already being presented, skipping additional alert")
                return
            }
            
            // Check if the view controller is visible before presenting
            guard self.isViewLoaded && self.view.window != nil else {
                print("View not in window hierarchy, canceling alert")
                return
            }
            
            self.isAlertPresented = true
            
            let alert = UIAlertController(
                title: "Camera Error",
                message: "Unable to access the camera. Please check your privacy settings.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.isAlertPresented = false
                // Notify delegate to dismiss this view controller
                self.delegate?.cameraPreviewViewControllerDidCancel(self)
            })
            
            self.present(alert, animated: true)
        }
    }
}

extension CameraPreviewViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("photoOutput didFinishProcessingPhoto called")
        
        // Handle any errors during photo capture
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            
            // In case of errors, fallback to mock photo in debug builds
            #if DEBUG
            print("DEBUG mode: Falling back to mock photo after camera error")
            mockCapturePhoto()
            return
            #else
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Show an error alert for photo capture error if not already showing another alert
                if !self.isAlertPresented {
                    self.isAlertPresented = true
                    
                    let alert = UIAlertController(
                        title: "Photo Capture Error",
                        message: "Unable to capture photo. Please try again.",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.isAlertPresented = false
                    })
                    
                    self.present(alert, animated: true)
                }
            }
            return
            #endif
        }
        
        // Ensure we have valid image data
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error: Unable to get file data representation from photo")
            
            // In case of errors, fallback to mock photo in debug builds
            #if DEBUG
            print("DEBUG mode: Falling back to mock photo after camera error")
            mockCapturePhoto()
            #endif
            return
        }
        
        // Convert data to UIImage
        guard let image = UIImage(data: imageData) else {
            print("Error: Unable to create UIImage from image data")
            
            // In case of errors, fallback to mock photo in debug builds
            #if DEBUG
            print("DEBUG mode: Falling back to mock photo after camera error")
            mockCapturePhoto()
            #endif
            return
        }
        
        print("Successfully captured photo")
        
        // Provide haptic feedback for successful capture
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Notify callback on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Call the completion handler if it exists
            if let onImageCaptured = self.onImageCaptured {
                print("Calling image captured callback")
                onImageCaptured(image)
            } else {
                print("Warning: Image captured but no callback registered")
            }
        }
    }
}
