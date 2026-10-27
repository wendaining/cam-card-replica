import Foundation

/// A user-created label (spec 十一). Stored by name; the id is the normalized
/// name so that "Conference" and "conference" cannot diverge.
struct CardTag: Codable, Hashable, Identifiable, Sendable {
    var name: String

    var id: String {
        name.lowercased()
    }
}

struct CardLibrary: Codable, Sendable {
    var cards: [BusinessCard]
    var tags: [CardTag]

    static let empty = CardLibrary(cards: [], tags: [])

    init(cards: [BusinessCard] = [], tags: [CardTag] = []) {
        self.cards = cards
        self.tags = tags
    }
}
