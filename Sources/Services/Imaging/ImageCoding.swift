import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Image serialization helpers shared by the scanner, the store and the tests.
enum ImageCoding {
    static func jpegData(from image: CGImage, quality: CGFloat = 0.92) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func orientation(of data: Data) -> CGImagePropertyOrientation {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = properties[kCGImagePropertyOrientation] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: raw)
        else { return .up }
        return orientation
    }

    /// Bakes the EXIF orientation into the pixels.
    ///
    /// Vision can take an orientation parameter, but Core Image cannot, so a
    /// rotated photo would be corrected with corners measured in a different
    /// space and come out skewed. Normalizing once at ingress removes the whole
    /// class of bugs (spec 7.3 "方向校正").
    static func applyingOrientation(
        _ image: CGImage,
        _ orientation: CGImagePropertyOrientation
    ) -> CGImage {
        guard orientation != .up else { return image }
        let source = CIImage(cgImage: image).oriented(forExifOrientation: Int32(orientation.rawValue))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let output = context.createCGImage(source, from: source.extent) else { return image }
        return output
    }

    /// Downscales so the longest edge is at most `maxDimension`; OCR quality is
    /// unaffected above ~2000 px and memory use drops sharply.
    static func downscaled(_ image: CGImage, maxDimension: CGFloat) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longest = max(width, height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
        guard let context = CGContext(
            data: nil,
            width: Int(target.width),
            height: Int(target.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: target))
        return context.makeImage() ?? image
    }
}
