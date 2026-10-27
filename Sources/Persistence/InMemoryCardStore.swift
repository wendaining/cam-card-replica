import Foundation

/// Test / preview double. Also used by UI tests launched with
/// `-ui-testing 1`, which is what makes T01–T20 deterministic.
final class InMemoryCardStore: CardStore {
    private(set) var library: CardLibrary
    private(set) var images: [String: Data] = [:]

    init(library: CardLibrary = .empty, images: [String: Data] = [:]) {
        self.library = library
        self.images = images
    }

    func load() throws -> CardLibrary { library }

    func save(_ library: CardLibrary) throws { self.library = library }

    func writeImage(_ data: Data, id: String) throws { images[id] = data }

    func readImage(id: String) -> Data? { images[id] }

    func deleteImage(id: String) { images.removeValue(forKey: id) }
}
