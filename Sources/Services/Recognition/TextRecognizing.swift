import CoreGraphics
import ImageIO

protocol TextRecognizing: Sendable {
    /// Runs OCR and returns every observation, unsorted, with normalized boxes.
    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) throws -> OCRResult
}
