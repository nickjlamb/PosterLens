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
    private var permissionSwitch: UISwitch!
    private var permissionLabel: UILabel!
    
    private var isGridVisible = false
    private var gridView: UIView?
    
    // Permission state
    var hasPermission: Bool = false {
        didSet {
            // Only update UI if view is loaded
            if isViewLoaded {
                updateCaptureButtonState()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupUI()
        // Update button state after UI is set up
        updateCaptureButtonState()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        updateGridView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
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
        previewLayer.connection?.videoOrientation = .portrait
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
        captureButton.alpha = 0.5 // Start with dimmed button until permission is granted
        
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
        
        // Create permission toggle and label
        permissionSwitch = UISwitch()
        permissionSwitch.translatesAutoresizingMaskIntoConstraints = false
        permissionSwitch.onTintColor = .systemBlue
        permissionSwitch.isOn = false
        permissionSwitch.addTarget(self, action: #selector(permissionToggled(_:)), for: .valueChanged)
        
        permissionLabel = UILabel()
        permissionLabel.translatesAutoresizingMaskIntoConstraints = false
        permissionLabel.text = "I have permission to photograph this poster"
        permissionLabel.textColor = .white
        permissionLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        permissionLabel.numberOfLines = 0
        permissionLabel.textAlignment = .right
        
        // Create a container view for permission controls
        let permissionContainer = UIView()
        permissionContainer.translatesAutoresizingMaskIntoConstraints = false
        permissionContainer.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        permissionContainer.layer.cornerRadius = 8
        
        // Add buttons to view
        view.addSubview(captureButton)
        view.addSubview(cancelButton)
        view.addSubview(flashButton)
        view.addSubview(gridButton)
        view.addSubview(permissionContainer)
        permissionContainer.addSubview(permissionLabel)
        permissionContainer.addSubview(permissionSwitch)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80),
            
            permissionContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            permissionContainer.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -20),
            permissionContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            permissionContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            permissionLabel.leadingAnchor.constraint(equalTo: permissionContainer.leadingAnchor, constant: 12),
            permissionLabel.centerYAnchor.constraint(equalTo: permissionContainer.centerYAnchor),
            permissionLabel.trailingAnchor.constraint(equalTo: permissionSwitch.leadingAnchor, constant: -8),
            
            permissionSwitch.trailingAnchor.constraint(equalTo: permissionContainer.trailingAnchor, constant: -12),
            permissionSwitch.centerYAnchor.constraint(equalTo: permissionContainer.centerYAnchor),
            
            permissionContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            
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
        
        // Add tap gesture recognizer for focus
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func capturePhoto() {
        // Check if we have permission
        guard hasPermission else {
            // Provide feedback that permission is required
            showPermissionRequiredAnimation()
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
        
        // Configure photo settings
        let settings = AVCapturePhotoSettings()
        
        // Enable flash if available
        if let device = AVCaptureDevice.default(for: .video),
           device.hasFlash {
            settings.flashMode = device.isTorchActive ? .on : .off
        }
        
        // Capture the photo
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // Handle permission toggle changes
    @objc private func permissionToggled(_ sender: UISwitch) {
        hasPermission = sender.isOn
        
        // Notify delegate about permission change
        delegate?.cameraPreviewViewControllerDidTogglePermission(self, hasPermission: hasPermission)
        
        // Provide haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        if sender.isOn {
            // Highlight the capture button briefly to draw attention
            UIView.animate(withDuration: 0.3, animations: {
                self.captureButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                self.captureButton.alpha = 1.0
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    self.captureButton.transform = CGAffineTransform.identity
                }
            }
        }
    }
    
    // Update the capture button state based on permission
    private func updateCaptureButtonState() {
        // Add nil check to prevent crash
        guard captureButton != nil else { return }
        
        UIView.animate(withDuration: 0.2) {
            self.captureButton.alpha = self.hasPermission ? 1.0 : 0.5
        }
    }
    
    // Show animation indicating permission is required
    private func showPermissionRequiredAnimation() {
        // Add nil checks to prevent crashes
        guard permissionSwitch != nil, permissionLabel != nil else { return }
        
        // Shake the permission switch to draw attention
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-10.0, 10.0, -8.0, 8.0, -5.0, 5.0, 0.0]
        permissionSwitch.layer.add(animation, forKey: "shake")
        
        // Highlight the permission label
        UIView.animate(withDuration: 0.3, animations: {
            self.permissionLabel.textColor = UIColor.systemRed
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5) {
                self.permissionLabel.textColor = UIColor.white
            }
        }
        
        // Provide error haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
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
            // Create new grid view
            let newGridView = createGridView()
            view.addSubview(newGridView)
            gridView = newGridView
        }
    }
    
    private func createGridView() -> UIView {
        let gridView = UIView(frame: previewLayer.frame)
        gridView.isUserInteractionEnabled = false
        
        // Create horizontal lines
        for i in 1...2 {
            let horizontalLine = UIView()
            horizontalLine.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            horizontalLine.translatesAutoresizingMaskIntoConstraints = false
            gridView.addSubview(horizontalLine)
            
            NSLayoutConstraint.activate([
                horizontalLine.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
                horizontalLine.trailingAnchor.constraint(equalTo: gridView.trailingAnchor),
                horizontalLine.centerYAnchor.constraint(equalTo: gridView.topAnchor, constant: gridView.frame.height / 3 * CGFloat(i)),
                horizontalLine.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }
        
        // Create vertical lines
        for i in 1...2 {
            let verticalLine = UIView()
            verticalLine.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            verticalLine.translatesAutoresizingMaskIntoConstraints = false
            gridView.addSubview(verticalLine)
            
            NSLayoutConstraint.activate([
                verticalLine.topAnchor.constraint(equalTo: gridView.topAnchor),
                verticalLine.bottomAnchor.constraint(equalTo: gridView.bottomAnchor),
                verticalLine.centerXAnchor.constraint(equalTo: gridView.leadingAnchor, constant: gridView.frame.width / 3 * CGFloat(i)),
                verticalLine.widthAnchor.constraint(equalToConstant: 0.5)
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
