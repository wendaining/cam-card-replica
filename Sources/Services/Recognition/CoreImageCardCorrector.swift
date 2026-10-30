import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Perspective correction with Core Image (spec 7.3).
final class CoreImageCardCorrector: ImageCorrecting {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func correct(_ image: CGImage, quad: Quad) throws -> CGImage {
        // Detection fallback and "use whole image" need no geometric change.
        // Rendering an identity perspective transform still changes decoded
        // pixels through interpolation/color conversion, damaging small text.
        if quad == .fullFrame {
            return image
        }
        let invalid = Quad(
            topLeft: .zero, topRight: .zero, bottomRight: .zero, bottomLeft: .zero
        )
        guard quad != invalid, quad.isPlausible || quad.area > 0 else {
            throw ImageCorrectionError.invalidQuad
        }

        let source = CIImage(cgImage: image)
        let size = CGSize(width: image.width, height: image.height)
        // Quad corners use a top-left origin (the convention across the app);
        // Core Image works bottom-left, so the vertical axis has to be flipped
        // here — otherwise the corrected card comes out upside down and OCR
        // returns mirrored garbage (observed on the photographed fixtures).
        let points = quad.pixelPoints(in: size).map { point in
            CGPoint(x: point.x, y: size.height - point.y)
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = source
        filter.topLeft = points[0]
        filter.topRight = points[1]
        filter.bottomRight = points[2]
        filter.bottomLeft = points[3]

        guard let output = filter.outputImage, let result = context.createCGImage(output, from: output.extent) else {
            throw ImageCorrectionError.renderFailed
        }
        return result
    }
}
