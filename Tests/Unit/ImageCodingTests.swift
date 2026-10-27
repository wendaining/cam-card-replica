@testable import CamCardReplica
import CoreGraphics
import ImageIO
import XCTest

final class ImageCodingTests: XCTestCase {
    private func makeImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    func testUprightImageIsReturnedUnchanged() {
        let image = makeImage(width: 100, height: 50)
        let result = ImageCoding.applyingOrientation(image, .up)
        XCTAssertEqual(result.width, 100)
        XCTAssertEqual(result.height, 50)
    }

    func testRightOrientationSwapsTheDimensions() {
        let image = makeImage(width: 100, height: 50)
        let result = ImageCoding.applyingOrientation(image, .right)
        XCTAssertEqual(result.width, 50, "a 90° rotation must swap width and height")
        XCTAssertEqual(result.height, 100)
    }

    func testUpsideDownKeepsTheDimensions() {
        let image = makeImage(width: 100, height: 50)
        let result = ImageCoding.applyingOrientation(image, .down)
        XCTAssertEqual(result.width, 100)
        XCTAssertEqual(result.height, 50)
    }

    func testJPEGRoundTripKeepsTheSize() throws {
        let image = makeImage(width: 120, height: 80)
        let data = try XCTUnwrap(ImageCoding.jpegData(from: image))
        let decoded = try XCTUnwrap(ImageCoding.cgImage(from: data))
        XCTAssertEqual(decoded.width, 120)
        XCTAssertEqual(decoded.height, 80)
    }
}
