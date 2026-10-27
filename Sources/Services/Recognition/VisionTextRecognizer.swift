import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Apple Vision based OCR.
///
/// Chosen over a cloud OCR API because the assignment compares *our* output
/// against the reference app on a fixed corpus: the same image must produce the
/// same text on every run, offline, with no per-call cost or quota (ADR-0001).
final class VisionTextRecognizer: TextRecognizing {
    struct Config: Sendable {
        var languages: [String] = ["zh-Hans", "en-US"]
        var level: VNRequestTextRecognitionLevel = .accurate
        var usesLanguageCorrection = true
        var minimumTextHeight: Float = 0.008
    }

    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    func recognize(image: CGImage, orientation: CGImagePropertyOrientation = .up) throws -> OCRResult {
        let started = CFAbsoluteTimeGetCurrent()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = config.level
        request.recognitionLanguages = config.languages
        request.usesLanguageCorrection = config.usesLanguageCorrection
        request.minimumTextHeight = config.minimumTextHeight

        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let lines: [OCRTextLine] = observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            // Vision uses a bottom-left origin; the rest of the app assumes
            // top-left, which is what SwiftUI and the crop overlay expect.
            let box = observation.boundingBox
            let normalized = CGRect(
                x: box.minX,
                y: 1 - box.maxY,
                width: box.width,
                height: box.height
            )
            return OCRTextLine(
                text: candidate.string,
                boundingBox: normalized,
                confidence: candidate.confidence
            )
        }

        let rawText = lines
            .sorted { $0.boundingBox.minY < $1.boundingBox.minY }
            .map(\.text)
            .joined(separator: "\n")

        return OCRResult(
            lines: lines,
            rawText: rawText,
            imageSize: CGSize(width: image.width, height: image.height),
            duration: CFAbsoluteTimeGetCurrent() - started,
            languages: config.languages
        )
    }
}
