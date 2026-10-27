import Foundation
import Observation

/// Single source of truth for the card list.
///
/// Every mutation goes through here and is persisted immediately, which is what
/// makes T18 (kill & relaunch) pass without any extra "save" button plumbing.
@MainActor
@Observable
final class CardLibraryModel {
    private(set) var cards: [BusinessCard] = []
    private(set) var tags: [CardTag] = []
    private(set) var lastErrorMessage: String?

    private let store: CardStore
    private let now: () -> Date

    init(store: CardStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
        reload()
    }

    // MARK: - Queries

    var isEmpty: Bool { cards.isEmpty }

    func card(id: UUID) -> BusinessCard? {
        cards.first { $0.id == id }
    }

    func cards(matching query: String, tag: String?) -> [BusinessCard] {
        let filtered = cards
            .filter { card in
                guard let tag else { return true }
                return card.tags.contains(tag)
            }
            .filter { $0.matches(query: query) }
        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }

    func imageData(for card: BusinessCard, original: Bool = false) -> Data? {
        let id = original ? card.originalImageID : (card.processedImageID ?? card.originalImageID)
        guard let id else { return nil }
        return store.readImage(id: id)
    }

    /// Tags that at least one card uses, plus user-created ones.
    var usedTags: [CardTag] {
        let inUse = Set(cards.flatMap(\.tags))
        return tags.filter { inUse.contains($0.name) }
    }

    // MARK: - Commands

    func reload() {
        do {
            let library = try store.load()
            cards = library.cards
            tags = library.tags
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func add(_ card: BusinessCard) -> BusinessCard {
        var card = card
        card.updatedAt = now()
        cards.append(card)
        for tag in card.tags { ensureTag(named: tag) }
        persist()
        return card
    }

    func update(_ card: BusinessCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        var updated = card
        updated.updatedAt = now()
        cards[index] = updated
        for tag in updated.tags { ensureTag(named: tag) }
        persist()
    }

    func delete(_ card: BusinessCard) {
        cards.removeAll { $0.id == card.id }
        if let id = card.originalImageID { store.deleteImage(id: id) }
        if let id = card.processedImageID, id != card.originalImageID { store.deleteImage(id: id) }
        persist()
    }

    func delete(at offsets: IndexSet, in list: [BusinessCard]) {
        let victims = offsets.compactMap { index in list.indices.contains(index) ? list[index] : nil }
        victims.forEach(delete)
    }

    // MARK: - Images

    func saveImage(_ data: Data) throws -> String {
        let id = UUID().uuidString
        try store.writeImage(data, id: id)
        return id
    }

    // MARK: - Tags

    @discardableResult
    func ensureTag(named name: String) -> CardTag? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = tags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let tag = CardTag(name: trimmed)
        tags.append(tag)
        persist()
        return tag
    }

    func deleteTag(named name: String) {
        tags.removeAll { $0.name == name }
        for index in cards.indices {
            cards[index].tags.removeAll { $0 == name }
        }
        persist()
    }

    func setTags(_ newTags: [String], on card: BusinessCard) {
        var updated = card
        let cleaned = newTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        updated.tags = Array(Set(cleaned)).sorted()
        update(updated)
    }

    // MARK: - Private

    private func persist() {
        do {
            try store.save(CardLibrary(cards: cards, tags: tags))
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
