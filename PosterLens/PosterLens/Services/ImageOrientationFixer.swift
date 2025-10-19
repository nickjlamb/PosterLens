import UIKit
import CoreGraphics
import CoreImage

/// Utility for fixing image orientation by actually rotating pixels
final class ImageOrientationFixer {

    /// Fixes the orientation of an image by rendering it with correct rotation
    /// This actually rotates the pixel data, not just the metadata
    static func fixOrientation(_ image: UIImage) -> UIImage {
        // If already correct orientation, return as-is
        guard image.imageOrientation != .up else {
            print("🔄 fixOrientation: already .up, skipping")
            return image
        }

        print("🔄 fixOrientation START: size=\(image.size), orientation=\(image.imageOrientation.rawValue)")

        // Map UIImage.Orientation to EXIF orientation
        let exifOrientation: Int32
        switch image.imageOrientation {
        case .up: exifOrientation = 1
        case .down: exifOrientation = 3
        case .left: exifOrientation = 8
        case .right: exifOrientation = 6
        case .upMirrored: exifOrientation = 2
        case .downMirrored: exifOrientation = 4
        case .leftMirrored: exifOrientation = 5
        case .rightMirrored: exifOrientation = 7
        @unknown default: exifOrientation = 1
        }

        print("🔄 Mapping UIImage orientation \(image.imageOrientation.rawValue) to EXIF \(exifOrientation)")

        // Use CIImage which properly handles orientation
        guard let ciImage = CIImage(image: image) else {
            print("❌ Failed to create CIImage")
            return image
        }

        // Apply orientation to actually transform the pixels
        let oriented = ciImage.oriented(forExifOrientation: exifOrientation)

        // Render to CGImage
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(oriented, from: oriented.extent) else {
            print("❌ Failed to render CIImage")
            return image
        }

        let fixedImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        print("🔄 fixOrientation END: size=\(fixedImage.size), orientation=\(fixedImage.imageOrientation.rawValue)")

        return fixedImage
    }

    /// Downscales an image to fit within a maximum dimension while maintaining aspect ratio
    static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrentDimension = max(size.width, size.height)

        // If already smaller than max, return as-is
        guard maxCurrentDimension > maxDimension else {
            return image
        }

        // Calculate new size
        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        // Render at new size
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))

        guard let scaledImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }

        return scaledImage
    }

    /// Complete processing: fix orientation and downscale
    static func processForOCR(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        // Step 1: Fix orientation
        let orientationFixed = fixOrientation(image)

        // Step 2: Downscale
        let downscaled = downscale(orientationFixed, maxDimension: maxDimension)

        return downscaled
    }
}
