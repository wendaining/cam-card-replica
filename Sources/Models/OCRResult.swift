import CoreGraphics
import Foundation

/// One recognized text observation.
struct OCRTextLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    /// Normalized text as returned by the recognizer (whitespace collapsed).
    var text: String
    /// Rect in image space, normalized to 0...1, **origin top-left**.
    var boundingBox: CGRect
    /// Recognizer confidence, 0...1.
    var confidence: Float

    init(id: UUID = UUID(), text: String, boundingBox: CGRect, confidence: Float) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }

    var centerY: CGFloat {
        boundingBox.midY
    }

    var height: CGFloat {
        boundingBox.height
    }

    var minX: CGFloat {
        boundingBox.minX
    }
}

/// Everything the OCR stage produces. Kept verbatim so that the benchmark in
/// `docs/reports/ocr-accuracy.md` can be reproduced from a saved run.
struct OCRResult: Codable, Hashable, Sendable {
    var lines: [OCRTextLine]
    var rawText: String
    var imageSize: CGSize
    var duration: TimeInterval
    var languages: [String]

    static let empty = OCRResult(lines: [], rawText: "", imageSize: .zero, duration: 0, languages: [])

    /// Lines sorted the way a human reads them: top to bottom, then left to
    /// right within a visual row (two-column cards depend on this).
    var readingOrderedLines: [OCRTextLine] {
        let sorted = lines.sorted { $0.centerY < $1.centerY }
        var rows: [[OCRTextLine]] = []
        for line in sorted {
            if var last = rows.last, let anchor = last.first,
               abs(anchor.centerY - line.centerY) < max(0.012, anchor.height * 0.45) {
                last.append(line)
                rows[rows.count - 1] = last
            } else {
                rows.append([line])
            }
        }
        return rows.flatMap { $0.sorted { $0.minX < $1.minX } }
    }
}
