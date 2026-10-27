@testable import CamCardReplica
import XCTest

final class CardDetectorTests: XCTestCase {
    func testFullFrameIsPlausible() {
        XCTAssertTrue(Quad.fullFrame.isPlausible)
        XCTAssertEqual(Quad.fullFrame.area, 1, accuracy: 0.001)
    }

    func testTinyQuadIsRejected() {
        let tiny = Quad(
            topLeft: CGPoint(x: 0.1, y: 0.1),
            topRight: CGPoint(x: 0.2, y: 0.1),
            bottomRight: CGPoint(x: 0.2, y: 0.15),
            bottomLeft: CGPoint(x: 0.1, y: 0.15)
        )
        XCTAssertFalse(tiny.isPlausible, "a 10% x 5% rectangle is not a card")
    }

    func testClampingKeepsPointsInsideTheImage() {
        let quad = Quad(
            topLeft: CGPoint(x: -0.2, y: -0.1),
            topRight: CGPoint(x: 1.3, y: 0.0),
            bottomRight: CGPoint(x: 1.2, y: 1.4),
            bottomLeft: CGPoint(x: 0.0, y: 1.9)
        ).clamped()
        for point in quad.points {
            XCTAssertTrue((0 ... 1).contains(point.x))
            XCTAssertTrue((0 ... 1).contains(point.y))
        }
    }

    func testPixelConversionScalesToImageSize() {
        let pixels = Quad.fullFrame.pixelPoints(in: CGSize(width: 200, height: 100))
        XCTAssertEqual(pixels[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(pixels[2], CGPoint(x: 200, y: 100))
    }

    private func fixtureImage(_ name: String) throws -> CGImage {
        guard let url = Bundle(for: Self.self).url(forResource: "Fixtures", withExtension: nil)?
            .appendingPathComponent(name),
            let data = try? Data(contentsOf: url),
            let image = ImageCoding.cgImage(from: data) else {
            throw XCTSkip("fixture not bundled")
        }
        return image
    }

    /// T06: a photographed card (card on a desk) must be located inside the frame.
    func testDetectsCardOnPhotographedFixture() throws {
        let image = try fixtureImage("zh-01-photo.jpg")
        let quad = try VisionCardDetector().detectCard(in: image, orientation: .up)
        XCTAssertNotNil(quad, "the card sits on a contrasting desk and must be found")
        XCTAssertGreaterThan(quad?.area ?? 0, 0.1)
        XCTAssertLessThan(quad?.area ?? 1, 1.0, "the detected card must be smaller than the photo")
    }

    /// T06 with a broken outline: a finger covers one corner of the card.
    /// Detection must still locate the card, otherwise the pipeline falls back
    /// to the whole photo and the user has to drag all four corners by hand.
    func testDetectsCardWithOneCornerOccluded() throws {
        let image = try fixtureImage("bi-14-photo-occluded.jpg")
        let quad = try VisionCardDetector().detectCard(in: image, orientation: .up)
        XCTAssertNotNil(quad, "an interrupted outline should still be detected")
        XCTAssertGreaterThan(quad?.area ?? 0, 0.1)
    }

    /// A full-bleed render has no background edges: detection legitimately fails
    /// and the caller falls back to the whole frame (spec 7.3.1).
    func testFullBleedRenderFallsBackToWholeImage() throws {
        let image = try fixtureImage("zh-01.jpg")
        let quad = try VisionCardDetector().detectCard(in: image, orientation: .up)
        XCTAssertNil(quad, "nothing to detect when the card fills the frame")
    }
}
