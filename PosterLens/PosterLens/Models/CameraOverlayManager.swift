import UIKit
import AVFoundation

// Enum to track current overlay mode
enum OverlayMode {
    case none
    case grid
    case posterFrame
}

// Class to manage camera overlays
class CameraOverlayManager {
    // Current overlay mode - set to posterFrame by default
    private(set) var currentMode: OverlayMode = .posterFrame
    
    // Current overlay view
    private var overlayView: UIView?
    
    // Reference to the parent view that will contain the overlays
    private weak var containerView: UIView?
    
    init(containerView: UIView) {
        self.containerView = containerView
        // Initialize with poster frame visible
        updateOverlay()
    }
    
    // Cycle to the next overlay mode
    func cycleToNextMode() -> OverlayMode {
        switch currentMode {
        case .none:
            currentMode = .grid
        case .grid:
            currentMode = .posterFrame
        case .posterFrame:
            currentMode = .none
        }
        
        updateOverlay()
        return currentMode
    }
    
    // Set a specific overlay mode
    func setMode(_ mode: OverlayMode) {
        guard currentMode != mode else { return }
        currentMode = mode
        updateOverlay()
    }
    
    // Update the overlay based on current mode
    func updateOverlay() {
        // Remove existing overlay view
        overlayView?.removeFromSuperview()
        overlayView = nil
        
        // Make sure container view exists
        guard let containerView = containerView else { return }
        
        // Create and add appropriate overlay based on current mode
        switch currentMode {
        case .grid:
            let newOverlayView = createGridView(in: containerView)
            containerView.addSubview(newOverlayView)
            overlayView = newOverlayView
        case .posterFrame:
            let newOverlayView = createPosterFrameView(in: containerView)
            containerView.addSubview(newOverlayView)
            overlayView = newOverlayView
        case .none:
            // No overlay
            break
        }
    }
    
    // Create grid view
    private func createGridView(in containerView: UIView) -> UIView {
        let gridView = UIView(frame: containerView.bounds)
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
    
    // Create poster frame view
    private func createPosterFrameView(in containerView: UIView) -> UIView {
        let frameView = UIView(frame: containerView.bounds)
        frameView.isUserInteractionEnabled = false
        
        // Create semi-transparent overlay for outside the frame
        let overlayView = UIView(frame: frameView.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        frameView.addSubview(overlayView)
        
        // Calculate frame dimensions - use landscape proportions (3:2 aspect ratio)
        // and adjust based on device orientation
        let isLandscape = frameView.frame.width > frameView.frame.height
        
        let frameWidth: CGFloat
        let frameHeight: CGFloat
        
        if isLandscape {
            // In landscape, make frame 85% of width
            frameWidth = frameView.frame.width * 0.85
            frameHeight = frameWidth * 2/3 // 3:2 aspect ratio for landscape poster
        } else {
            // In portrait, make frame 85% of width
            frameWidth = frameView.frame.width * 0.85
            frameHeight = frameWidth * 3/2 // 3:2 aspect ratio for portrait poster
        }
        
        // Create frame mask (to make the frame area transparent)
        let framePath = UIBezierPath(rect: frameView.bounds)
        let frameRect = CGRect(
            x: (frameView.frame.width - frameWidth) / 2,
            y: (frameView.frame.height - frameHeight) / 2,
            width: frameWidth,
            height: frameHeight
        )
        let transparentPath = UIBezierPath(roundedRect: frameRect, cornerRadius: 8)
        framePath.append(transparentPath)
        framePath.usesEvenOddFillRule = true
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = framePath.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
        
        // Create the frame border
        let frameLayer = CAShapeLayer()
        frameLayer.path = UIBezierPath(roundedRect: frameRect, cornerRadius: 8).cgPath
        frameLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
        frameLayer.fillColor = UIColor.clear.cgColor
        frameLayer.lineWidth = 2.0
        frameView.layer.addSublayer(frameLayer)
        
        // Add corner indicators
        let cornerSize: CGFloat = min(frameWidth, frameHeight) * 0.1
        let corners = [
            CGPoint(x: frameRect.minX, y: frameRect.minY), // Top-left
            CGPoint(x: frameRect.maxX, y: frameRect.minY), // Top-right
            CGPoint(x: frameRect.minX, y: frameRect.maxY), // Bottom-left
            CGPoint(x: frameRect.maxX, y: frameRect.maxY)  // Bottom-right
        ]
        
        for corner in corners {
            // Determine if this is a left/right and top/bottom corner
            let isLeft = corner.x == frameRect.minX
            let isTop = corner.y == frameRect.minY
            
            // Create horizontal line
            let hLine = UIView()
            hLine.backgroundColor = UIColor.white
            hLine.frame = CGRect(
                x: isLeft ? corner.x : corner.x - cornerSize,
                y: corner.y - 1,
                width: cornerSize,
                height: 3
            )
            frameView.addSubview(hLine)
            
            // Create vertical line
            let vLine = UIView()
            vLine.backgroundColor = UIColor.white
            vLine.frame = CGRect(
                x: corner.x - 1,
                y: isTop ? corner.y : corner.y - cornerSize,
                width: 3,
                height: cornerSize
            )
            frameView.addSubview(vLine)
        }
        
        // Add label at the top
        let label = UILabel()
        label.text = "Align poster within frame"
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        frameView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: frameView.topAnchor, constant: frameRect.minY - 10)
        ])
        
        return frameView
    }
    
    // Update when container view changes size
    func updateForContainerBoundsChange() {
        updateOverlay()
    }
}
