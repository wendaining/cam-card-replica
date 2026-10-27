import Foundation

/// JSON + image files on disk.
///
/// Why not SwiftData (ADR-0003): the persistence requirements here are tiny
/// (a few dozen records), the schema is owned by this repo, and a plain
/// `Codable` file is trivially inspectable, diffable and testable — including
/// the "kill the app and relaunch" test, which only needs the file to exist.
final class FileCardStore: CardStore {
    private let root: URL
    private let imagesDirectory: URL
    private let libraryURL: URL
    private let queue = DispatchQueue(label: "com.wendaining.camcard.store")

    init(root: URL? = nil) {
        let base = root ?? FileCardStore.defaultRoot()
        self.root = base
        self.imagesDirectory = base.appendingPathComponent("Images", isDirectory: true)
        self.libraryURL = base.appendingPathComponent("library.json")
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    static func defaultRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("CamCardReplica", isDirectory: true)
    }

    func load() throws -> CardLibrary {
        guard FileManager.default.fileExists(atPath: libraryURL.path) else { return .empty }
        do {
            let data = try Data(contentsOf: libraryURL)
            return try Self.decoder.decode(CardLibrary.self, from: data)
        } catch {
            throw CardStoreError.corruptedLibrary(underlying: error)
        }
    }

    func save(_ library: CardLibrary) throws {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let data = try Self.encoder.encode(library)
            let temporary = libraryURL.appendingPathExtension("tmp")
            try data.write(to: temporary, options: .atomic)
            _ = try FileManager.default.replaceItemAt(libraryURL, withItemAt: temporary)
        } catch {
            throw CardStoreError.writeFailed(underlying: error)
        }
    }

    func writeImage(_ data: Data, id: String) throws {
        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            try data.write(to: imageURL(id), options: .atomic)
        } catch {
            throw CardStoreError.writeFailed(underlying: error)
        }
    }

    func readImage(id: String) -> Data? {
        try? Data(contentsOf: imageURL(id))
    }

    func deleteImage(id: String) {
        try? FileManager.default.removeItem(at: imageURL(id))
    }

    private func imageURL(_ id: String) -> URL {
        imagesDirectory.appendingPathComponent("\(id).jpg")
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
