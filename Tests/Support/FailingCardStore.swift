@testable import CamCardReplica
import Foundation

/// Deterministic disk/image failures, backed by a durable snapshot for reload checks.
final class FailingCardStore: CardStore {
    var library: CardLibrary = .empty
    var images: [String: Data] = [:]
    var failsSave = false
    var failingImageWrite: Int?
    private var imageWriteCount = 0

    func load() throws -> CardLibrary {
        library
    }

    func save(_ library: CardLibrary) throws {
        if failsSave {
            throw CardStoreError.writeFailed(underlying: CocoaError(.fileWriteOutOfSpace))
        }
        self.library = library
    }

    func writeImage(_ data: Data, id: String) throws {
        imageWriteCount += 1
        if imageWriteCount == failingImageWrite {
            throw CardStoreError.writeFailed(underlying: CocoaError(.fileWriteOutOfSpace))
        }
        images[id] = data
    }

    func readImage(id: String) -> Data? {
        images[id]
    }

    func deleteImage(id: String) {
        images.removeValue(forKey: id)
    }
}
