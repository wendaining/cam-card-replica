import CoreGraphics
import ImageIO

protocol CardDetecting: Sendable {
    /// Returns the detected card outline, or `nil` when no reliable rectangle
    /// exists (the caller then falls back to the full frame).
    func detectCard(in image: CGImage, orientation: CGImagePropertyOrientation) throws -> Quad?
}
