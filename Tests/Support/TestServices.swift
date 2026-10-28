@testable import CamCardReplica
import CoreGraphics
import Foundation
import ImageIO

struct EmptyRecognizer: TextRecognizing {
    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) throws -> OCRResult {
        .empty
    }
}

struct NoCardDetector: CardDetecting {
    func detectCard(in image: CGImage, orientation: CGImagePropertyOrientation) throws -> Quad? {
        nil
    }
}

struct IdentityCorrector: ImageCorrecting {
    func correct(_ image: CGImage, quad: Quad) throws -> CGImage {
        image
    }
}

@MainActor
enum TestServices {
    static func make(store: CardStore, recognizer: any TextRecognizing = EmptyRecognizer()) -> AppServices {
        AppServices(
            library: CardLibraryModel(store: store), recognizer: recognizer,
            detector: NoCardDetector(), corrector: IdentityCorrector(), exporter: ContactsExporter(),
            parser: HeuristicFieldParser(), permission: StubCameraPermission(status: .denied),
            fixtures: nil, configuration: .production
        )
    }

    static func image() -> CGImage {
        let context = CGContext(
            data: nil, width: 100, height: 60, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 60))
        return context.makeImage()!
    }
}
