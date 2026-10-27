import CoreGraphics
import Foundation

/// Four corners of the card in normalized image space (0...1, origin top-left).
struct Quad: Equatable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let fullFrame = Quad(
        topLeft: CGPoint(x: 0, y: 0),
        topRight: CGPoint(x: 1, y: 0),
        bottomRight: CGPoint(x: 1, y: 1),
        bottomLeft: CGPoint(x: 0, y: 1)
    )

    var points: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// Shoelace area, used to reject degenerate detections.
    var area: CGFloat {
        let pts = points
        var sum: CGFloat = 0
        for index in pts.indices {
            let current = pts[index]
            let next = pts[(index + 1) % pts.count]
            sum += current.x * next.y - next.x * current.y
        }
        return abs(sum) / 2
    }

    var isPlausible: Bool { area > 0.12 && area < 1.01 }

    /// Clamps every corner back into the unit square.
    func clamped() -> Quad {
        func clamp(_ point: CGPoint) -> CGPoint {
            CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        }
        return Quad(
            topLeft: clamp(topLeft),
            topRight: clamp(topRight),
            bottomRight: clamp(bottomRight),
            bottomLeft: clamp(bottomLeft)
        )
    }

    /// Converts to pixel coordinates for Core Image.
    func pixelPoints(in size: CGSize) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
