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
    
    // Always allow capture
    var hasPermission: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupUI()
        // Capture button is always enabled
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
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
        
        // Start observing device orientation changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
                                               
        // Enable device orientation notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Set initial orientation
        updatePreviewLayerVideoOrientation()
        
        // Start capture session
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop observing orientation changes
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
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
        // Use a slight delay to ensure animation happens after the device has fully rotated
        DispatchQueue.main.async { [weak self] in
            self?.updatePreviewLayerVideoOrientation()
        }
    }
    
    private func updatePreviewLayerVideoOrientation() {
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
        captureSession = AVCaptureSession()
        
        // Configure the session for high resolution capture
        if #available(iOS 16.0, *) {
            // First configure the session
            captureSession.beginConfiguration()
            
            // Set up the capture device
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  captureSession.canAddInput(videoDeviceInput) else {
                presentCameraSetupErrorAlert()
                captureSession.commitConfiguration()
                return
            }
            
            captureSession.addInput(videoDeviceInput)
            
            // Set up photo output
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                
                // Now that the session is configured and the device is connected,
                // we can safely check the supported dimensions
                let format = videoDevice.activeFormat
                if let dimensions = format.supportedMaxPhotoDimensions.first {
                    photoOutput.maxPhotoDimensions = dimensions
                } else {
                    print("No supported max photo dimensions found")
                }
                
                photoOutput.isLivePhotoCaptureEnabled = false
            }
            
            captureSession.commitConfiguration()
        } else {
            // Fallback for earlier iOS versions
            captureSession.beginConfiguration()
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                  captureSession.canAddInput(videoDeviceInput) else {
                presentCameraSetupErrorAlert()
                captureSession.commitConfiguration()
                return
            }
            
            captureSession.addInput(videoDeviceInput)
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
                photoOutput.isLivePhotoCaptureEnabled = false
            }
            
            captureSession.commitConfiguration()
        }
        
        // Set up the preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        updatePreviewLayerVideoOrientation()
    }
    
    private func setupUI() {
        // Add the preview layer to the view
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
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
        // Permission check removed - always allow capture
        
        // Animate the capture button
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = CGAffineTransform.identity
            }
        }
        
        // Configure photo settings
        let settings = AVCapturePhotoSettings()
        
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
        // Remove existing grid view if any
        gridView?.removeFromSuperview()
        
        if isGridVisible {
            // Create new grid view with animation
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
    
    private func presentCameraSetupErrorAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Camera Error",
                message: "Unable to access the camera. Please check your privacy settings.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

extension CameraPreviewViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error converting photo data to image")
            return
        }
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        DispatchQueue.main.async { [weak self] in
            self?.onImageCaptured?(image)
        }
    }
}
