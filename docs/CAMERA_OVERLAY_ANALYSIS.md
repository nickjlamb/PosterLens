# Camera Overlay & SwiftUI Button Layering Analysis

## Problem Summary
The info button in SwiftUI sometimes disappears when `CameraOverlayManager` is active, likely due to UIKit overlay views masking or blocking SwiftUI elements.

## Current Architecture Analysis

### 1. CameraOverlayManager Implementation (UIKit)

**File**: `PosterLens/Models/CameraOverlayManager.swift`

**Key Findings**:

```swift
// Lines 77-78: Grid overlay
let gridView = UIView(frame: containerView.bounds)
gridView.isUserInteractionEnabled = false  ✅ Good: Won't block touches

// Lines 119-121: Poster frame overlay
let overlayView = UIView(frame: frameView.bounds)
overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.2)  ⚠️ ISSUE
frameView.addSubview(overlayView)
```

**Issues Identified**:

1. **Visual Masking**: The poster frame overlay uses `UIColor.black.withAlphaComponent(0.2)` which creates a semi-transparent dark overlay covering the **entire container view**. Even though `isUserInteractionEnabled = false`, this overlay will **visually dim** anything beneath it, including SwiftUI views.

2. **Z-Order Conflict**: UIKit views added via `UIViewRepresentable` exist in a different rendering context than SwiftUI views. The rendering order is:
   ```
   Bottom → Top:
   1. SwiftUI background layers
   2. UIKit views (via UIViewRepresentable) ← Your overlays are here
   3. SwiftUI overlay layers (where your button should be)
   ```

   However, if the UIKit container view is added **after** SwiftUI calculates its layout, the UIKit view can end up on top.

3. **Frame Synchronization**: The overlay uses `frame: containerView.bounds`, which might not update correctly when the view hierarchy changes, potentially covering UI elements.

### 2. Current Integration Status

**Status**: CameraOverlayManager is **NOT currently integrated** in `CameraPreviewViewController.swift`

The class exists but isn't being used yet. This is actually **good news** - you can implement it correctly from the start.

## Root Cause of Button Disappearance

Even though you're not using CameraOverlayManager yet, the issue you're experiencing is likely due to:

1. **UIKit Preview Layer**: The `AVCaptureVideoPreviewLayer` in `CameraPreviewViewController` is a UIKit layer that fills the entire view
2. **SwiftUI/UIKit Bridging**: When you wrap `CameraPreviewViewController` with `UIViewControllerRepresentable`, the entire UIKit view hierarchy can interfere with SwiftUI's layout

The semi-transparent overlay (when added) will make this worse by adding another visual layer on top.

## Solutions

### Solution 1: Keep Button in SwiftUI (Recommended)

**Pros**: Clean separation, native SwiftUI behavior, easier to maintain
**Cons**: Requires careful z-ordering and coordinate space handling

**Implementation**:

```swift
// In your SwiftUI view wrapping the camera
ZStack {
    // Camera preview (UIKit)
    CameraPreviewRepresentable()

    // Overlay view (UIKit) - but made transparent where needed
    CameraOverlayRepresentable()
        .allowsHitTesting(false)  // Ensure no touch blocking

    // Info button (SwiftUI) - guaranteed to be on top
    VStack {
        HStack {
            Spacer()
            Button(action: { showingAboutView = true }) {
                Image(systemName: "info.circle")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        // Add background for visibility over dark overlay
                        Circle()
                            .fill(Color.white.opacity(0.2))
                    )
            }
            .padding(.top, 50)
            .padding(.trailing, 20)
        }
        Spacer()
    }
    .zIndex(999)  // High z-index
}
```

**Key Changes to CameraOverlayManager**:

```swift
// Modify createPosterFrameView to exclude the top-right corner
private func createPosterFrameView(in containerView: UIView) -> UIView {
    let frameView = UIView(frame: containerView.bounds)
    frameView.isUserInteractionEnabled = false

    // Create semi-transparent overlay
    let overlayView = UIView(frame: frameView.bounds)
    overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.2)

    // IMPORTANT: Add a transparent cutout for the info button area
    let buttonSafeArea = CGRect(
        x: frameView.frame.width - 100,  // 100pt from right
        y: 0,                             // Top of screen
        width: 100,                       // 100pt wide
        height: 100                       // 100pt tall
    )

    // Create mask with cutout
    let maskPath = UIBezierPath(rect: frameView.bounds)
    let buttonPath = UIBezierPath(rect: buttonSafeArea)
    maskPath.append(buttonPath)
    maskPath.usesEvenOddFillRule = true

    let maskLayer = CAShapeLayer()
    maskLayer.path = maskPath.cgPath
    maskLayer.fillRule = .evenOdd
    overlayView.layer.mask = maskLayer

    frameView.addSubview(overlayView)

    // ... rest of frame creation code
}
```

### Solution 2: Move Button to UIKit

**Pros**: Guaranteed same rendering context, simpler z-ordering
**Cons**: Loses SwiftUI benefits, more UIKit boilerplate

**Implementation**:

```swift
// Add to CameraPreviewViewController
class CameraPreviewViewController: UIViewController {
    // Add this property
    private var infoButton: UIButton!

    // In setupUI()
    private func setupUI() {
        // ... existing setup ...

        // Create info button
        infoButton = UIButton(type: .system)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
        infoButton.tintColor = .white
        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)

        // IMPORTANT: Add button AFTER overlay to ensure it's on top
        view.addSubview(infoButton)

        NSLayoutConstraint.activate([
            infoButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            infoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            infoButton.widthAnchor.constraint(equalToConstant: 44),
            infoButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Ensure button has highest z-position
        view.bringSubviewToFront(infoButton)
    }

    @objc private func infoButtonTapped() {
        // Notify SwiftUI via delegate or closure
        delegate?.cameraPreviewViewControllerDidTapInfo(self)
    }
}

// Update protocol
protocol CameraPreviewViewControllerDelegate: AnyObject {
    func cameraPreviewViewControllerDidCancel(_ controller: CameraPreviewViewController)
    func cameraPreviewViewControllerDidTogglePermission(_ controller: CameraPreviewViewController, hasPermission: Bool)
    func cameraPreviewViewControllerDidTapInfo(_ controller: CameraPreviewViewController)  // New
}
```

### Solution 3: Hybrid Approach with Overlay Exclusion Zones (Best of Both Worlds)

**Pros**: Flexible, maintains SwiftUI button, accommodates overlay
**Cons**: Slightly more complex coordination

**Implementation**:

```swift
// Update CameraOverlayManager to accept exclusion zones
class CameraOverlayManager {
    // Add property
    var exclusionZones: [CGRect] = []

    // Update createPosterFrameView
    private func createPosterFrameView(in containerView: UIView) -> UIView {
        let frameView = UIView(frame: containerView.bounds)
        frameView.isUserInteractionEnabled = false

        let overlayView = UIView(frame: frameView.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.2)

        // Create mask with exclusions
        let maskPath = UIBezierPath(rect: frameView.bounds)

        // Cut out exclusion zones
        for exclusion in exclusionZones {
            let exclusionPath = UIBezierPath(roundedRect: exclusion, cornerRadius: 8)
            maskPath.append(exclusionPath)
        }

        maskPath.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = maskPath.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer

        frameView.addSubview(overlayView)

        // ... rest of code
    }
}

// Usage in SwiftUI
struct CameraOverlayRepresentable: UIViewRepresentable {
    var overlayMode: OverlayMode
    var exclusionZones: [CGRect]  // Pass from SwiftUI

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let manager = CameraOverlayManager(containerView: containerView)
        manager.exclusionZones = exclusionZones
        manager.setMode(overlayMode)

        context.coordinator.manager = manager
        return containerView
    }
}
```

## Recommended Approach

**Use Solution 3 (Hybrid with Exclusion Zones)** because:

1. ✅ Maintains SwiftUI button benefits (animation, state management)
2. ✅ Prevents visual masking by excluding button area from dark overlay
3. ✅ Preserves ability to switch overlay modes
4. ✅ Future-proof for adding more UI elements
5. ✅ Clean separation of concerns

## Implementation Steps

1. **Modify CameraOverlayManager**:
   - Add `exclusionZones` property
   - Update `createPosterFrameView()` to apply exclusions to mask

2. **Create UIViewRepresentable wrapper**:
   ```swift
   struct CameraOverlayRepresentable: UIViewRepresentable {
       // Implementation as shown in Solution 3
   }
   ```

3. **Update SwiftUI camera view**:
   ```swift
   ZStack(alignment: .topTrailing) {
       CameraPreviewRepresentable()

       CameraOverlayRepresentable(
           overlayMode: currentOverlayMode,
           exclusionZones: [
               CGRect(x: screenWidth - 100, y: 0, width: 100, height: 100)
           ]
       )
       .allowsHitTesting(false)

       Button(...) { }
           .padding(.top, 50)
           .padding(.trailing, 20)
           .zIndex(999)
   }
   ```

4. **Add visibility enhancement to button**:
   ```swift
   Button(action: { showingAboutView = true }) {
       Image(systemName: "info.circle")
           .resizable()
           .frame(width: 24, height: 24)
           .foregroundColor(.white)
           .padding()
           .background(
               Circle()
                   .fill(Color.white.opacity(0.3))  // Helps visibility
                   .blur(radius: 2)
           )
           .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
   }
   ```

## Testing Checklist

- [ ] Info button visible in all overlay modes (.none, .grid, .posterFrame)
- [ ] Button responds to taps in all modes
- [ ] No visual artifacts or flickering during overlay mode changes
- [ ] Button remains visible during device rotation
- [ ] Dark overlay doesn't dim the button area
- [ ] Button maintains proper safe area spacing

## Additional Notes

### Why `isUserInteractionEnabled = false` Isn't Enough

Setting `isUserInteractionEnabled = false` only prevents the view from **receiving touch events**. It does **not** prevent visual masking. A semi-transparent black overlay will still dim whatever is beneath it, making white icons less visible.

### UIKit vs SwiftUI Rendering Order

When mixing UIKit and SwiftUI:
- SwiftUI renders its view hierarchy
- UIKit views added via `UIViewRepresentable` are inserted into the UIKit hosting view
- SwiftUI's `.overlay()` and `.zIndex()` only affect **other SwiftUI views**, not UIKit siblings
- To guarantee layering, use exclusion zones or add UI elements to the same context (all UIKit or coordinate carefully)

### Performance Considerations

The exclusion zone approach has minimal performance impact:
- Shape layer masks are GPU-accelerated
- Recalculating mask only happens on overlay mode changes
- No per-frame rendering overhead

---

**Created**: 2025-10-15
**Status**: Ready for implementation
**Priority**: High (affects UX)
