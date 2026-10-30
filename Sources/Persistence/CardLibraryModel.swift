import Foundation
import Observation

/// Only publishes mutations after the store commits. Image cleanup follows JSON deletion.
@MainActor
@Observable
final class CardLibraryModel {
    private(set) var cards: [BusinessCard] = []
    private(set) var tags: [CardTag] = []
    private(set) var lastErrorMessage: String?
    private var loadError: Error?
    private let store: CardStore
    private let now: () -> Date

    init(store: CardStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
        reload()
    }

    var isEmpty: Bool {
        cards.isEmpty
    }

    var loadErrorMessage: String? {
        loadError?.localizedDescription
    }

    func card(id: UUID) -> BusinessCard? {
        cards.first { $0.id == id }
    }

    func cards(matching query: String, tag: String?) -> [BusinessCard] {
        cards.filter { card in
            tag.map { tag in card.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } } ?? true
        }.filter { $0.matches(query: query) }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func imageData(for card: BusinessCard, original: Bool = false) -> Data? {
        let id = original ? card.originalImageID : (card.processedImageID ?? card.originalImageID)
        return id.flatMap { store.readImage(id: $0) }
    }

    var usedTags: [CardTag] {
        tags.filter { tag in cards.contains { $0.tags.contains(tag.name) } }
    }

    func reload() {
        do {
            let library = try canonicalized(store.load())
            cards = library.cards
            tags = library.tags
            loadError = nil
            lastErrorMessage = nil
        } catch {
            loadError = error
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func add(
        _ card: BusinessCard,
        originalImageData: Data? = nil,
        processedImageData: Data? = nil,
        deletingTags: Set<String> = []
    ) throws -> BusinessCard {
        var candidate = card
        var newImageIDs: [String] = []
        do {
            if let data = originalImageData {
                let id = UUID().uuidString
                newImageIDs.append(id)
                try store.writeImage(data, id: id)
                candidate.originalImageID = id
            }
            if let data = processedImageData {
                let id = UUID().uuidString
                newImageIDs.append(id)
                try store.writeImage(data, id: id)
                candidate.processedImageID = id
            }
            candidate.updatedAt = now()
            try commit(removingTags(deletingTags, from: CardLibrary(cards: cards + [candidate], tags: tags)))
            return self.card(id: candidate.id) ?? candidate
        } catch {
            newImageIDs.forEach { store.deleteImage(id: $0) }
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func update(_ card: BusinessCard, deletingTags: Set<String> = []) throws {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updatedCards = cards
        var updated = card
        updated.updatedAt = now()
        updatedCards[index] = updated
        try commit(removingTags(deletingTags, from: CardLibrary(cards: updatedCards, tags: tags)))
    }

    func delete(_ card: BusinessCard) throws {
        try delete(at: IndexSet(cards.indices.filter { cards[$0].id == card.id }), in: cards)
    }

    func delete(at offsets: IndexSet, in list: [BusinessCard]) throws {
        let victims = offsets.compactMap { list.indices.contains($0) ? list[$0] : nil }
        let ids = Set(victims.map(\.id))
        let remaining = cards.filter { !ids.contains($0.id) }
        try commit(CardLibrary(cards: remaining, tags: tags))
        let retainedImages = Set(remaining.flatMap { [$0.originalImageID, $0.processedImageID].compactMap { $0 } })
        let deletedImages = Set(victims.flatMap { [$0.originalImageID, $0.processedImageID].compactMap { $0 } })
        deletedImages.subtracting(retainedImages).forEach { store.deleteImage(id: $0) }
    }

    func saveImage(_ data: Data) throws -> String {
        let id = UUID().uuidString
        try store.writeImage(data, id: id)
        return id
    }

    @discardableResult
    func ensureTag(named name: String) throws -> CardTag? {
        guard let name = name.nilIfBlank else { return nil }
        if let tag = tags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return tag
        }
        try commit(CardLibrary(cards: cards, tags: tags + [CardTag(name: name)]))
        return tags.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func deleteTag(named name: String) throws {
        try commit(removingTags([name], from: CardLibrary(cards: cards, tags: tags)))
    }

    func setTags(_ newTags: [String], on card: BusinessCard) throws {
        var updated = card
        updated.tags = newTags
        try update(updated)
    }

    private func removingTags(_ deleted: Set<String>, from library: CardLibrary) -> CardLibrary {
        let keys = Set(deleted.map { $0.lowercased() })
        var result = library
        result.tags.removeAll { keys.contains($0.name.lowercased()) }
        for index in result.cards.indices {
            result.cards[index].tags.removeAll { keys.contains($0.lowercased()) }
        }
        return result
    }

    private func canonicalized(_ library: CardLibrary) -> CardLibrary {
        var names: [String: String] = [:]
        for name in library.tags.map(\.name) + library.cards.flatMap(\.tags) {
            if let trimmed = name.nilIfBlank,
               names[trimmed.lowercased()] == nil {
                names[trimmed.lowercased()] = trimmed
            }
        }
        var result = library
        result.tags = names.values.sorted().map { CardTag(name: $0) }
        for index in result.cards.indices {
            result.cards[index].tags = Array(Set(result.cards[index].tags.compactMap {
                $0.nilIfBlank.flatMap { names[$0.lowercased()] }
            })).sorted()
        }
        return result
    }

    private func commit(_ library: CardLibrary) throws {
        do {
            // A failed load must never be overwritten by an apparently empty library.
            if let loadError {
                throw loadError
            }
            let candidate = canonicalized(library)
            try store.save(candidate)
            cards = candidate.cards
            tags = candidate.tags
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }
}
