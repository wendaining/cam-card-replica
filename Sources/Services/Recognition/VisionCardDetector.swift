import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Rectangle detection tuned for business cards.
///
/// A CR80 card is 85.6 x 54 mm, i.e. an aspect ratio of ~1.585, which lets the
/// detector reject laptop screens, windows and table edges before they reach the
/// crop UI (spec 7.3 / T06).
final class VisionCardDetector: CardDetecting {
    struct Config: Sendable {
        var minimumAspectRatio: Float = 1.25
        var maximumAspectRatio: Float = 2.4
        var minimumSize: Float = 0.15
        var quadratureTolerance: Float = 35
        /// Tried in order: a strict pass first, then a permissive retry for
        /// low-contrast photos (dark backgrounds, shadows).
        var confidenceLevels: [Float] = [0.75, 0.55, 0.35]
    }

    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    func detectCard(in image: CGImage, orientation: CGImagePropertyOrientation = .up) throws -> Quad? {
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        for confidence in config.confidenceLevels {
            let request = VNDetectRectanglesRequest()
            request.minimumAspectRatio = config.minimumAspectRatio
            request.maximumAspectRatio = config.maximumAspectRatio
            request.minimumSize = config.minimumSize
            request.quadratureTolerance = config.quadratureTolerance
            request.minimumConfidence = confidence
            request.maximumObservations = 3
            try handler.perform([request])
            guard let results = request.results, !results.isEmpty else { continue }
            let quads = results.map(Self.quad(from:)).filter(\.isPlausible)
            guard let best = quads.max(by: { $0.area < $1.area }) else { continue }
            return best.clamped()
        }
        return nil
    }

    /// Vision's corners use a bottom-left origin; flip Y so the result matches
    /// the app-wide top-left convention.
    private static func quad(from observation: VNRectangleObservation) -> Quad {
        func flip(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x, y: 1 - point.y)
        }
        return Quad(
            topLeft: flip(observation.topLeft),
            topRight: flip(observation.topRight),
            bottomRight: flip(observation.bottomRight),
            bottomLeft: flip(observation.bottomLeft)
        )
    }
}
