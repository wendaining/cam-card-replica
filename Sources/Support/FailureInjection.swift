import CoreGraphics
import Foundation
import ImageIO

/// Used only when the composition root receives explicit UI-testing failure flags.
final class SaveFailingStore: CardStore {
    private let base: CardStore
    init(base: CardStore) {
        self.base = base
    }

    func load() throws -> CardLibrary {
        try base.load()
    }

    func save(_ library: CardLibrary) throws {
        throw CardStoreError.writeFailed(underlying: CocoaError(.fileWriteOutOfSpace))
    }

    func writeImage(_ data: Data, id: String) throws {
        try base.writeImage(data, id: id)
    }

    func readImage(id: String) -> Data? {
        base.readImage(id: id)
    }

    func deleteImage(id: String) {
        base.deleteImage(id: id)
    }
}

struct UITestTextRecognizer: TextRecognizing {
    var fails: Bool
    func recognize(image: CGImage, orientation: CGImagePropertyOrientation) throws -> OCRResult {
        if fails {
            throw CocoaError(.fileReadCorruptFile)
        }
        return .empty
    }
}
