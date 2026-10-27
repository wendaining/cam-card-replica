import XCTest
@testable import CamCardReplica

@MainActor
final class CardLibraryModelTests: XCTestCase {
    private func makeModel() -> CardLibraryModel {
        CardLibraryModel(store: InMemoryCardStore())
    }

    private func card(name: String = "朱宏明") -> BusinessCard {
        BusinessCard(name: name, company: "同济大学", jobTitle: "教授", tags: ["Conference"])
    }

    func testStartsEmpty() {
        let model = makeModel()
        XCTAssertTrue(model.isEmpty)
    }

    func testAddPersistsImmediately() {
        let store = InMemoryCardStore()
        let model = CardLibraryModel(store: store)
        model.add(card())
        XCTAssertEqual(model.cards.count, 1)
        XCTAssertEqual(store.library.cards.count, 1, "add must write through the store (T18)")
    }

    func testUpdateChangesFields() {
        let model = makeModel()
        let saved = model.add(card())
        var edited = saved
        edited.name = "朱宏明（教授）"
        model.update(edited)
        XCTAssertEqual(model.card(id: saved.id)?.name, "朱宏明（教授）")
    }

    func testDeleteRemovesCardAndImages() throws {
        let store = InMemoryCardStore()
        let model = CardLibraryModel(store: store)
        let imageID = try model.saveImage(Data([0x01]))
        var saved = card()
        saved.originalImageID = imageID
        let stored = model.add(saved)

        model.delete(stored)
        XCTAssertTrue(model.cards.isEmpty)
        XCTAssertNil(store.readImage(id: imageID), "images must not leak after delete")
    }

    func testSearchAndTagFilter() {
        let model = makeModel()
        model.add(BusinessCard(name: "朱宏明", company: "同济大学", tags: ["Professor"]))
        model.add(BusinessCard(name: "David Chen", company: "ABC Technologies", tags: ["Customer"]))

        XCTAssertEqual(model.cards(matching: "David", tag: nil).count, 1)
        XCTAssertEqual(model.cards(matching: "", tag: "Professor").count, 1)
        XCTAssertEqual(model.cards(matching: "同济", tag: "Customer").count, 0)
    }

    func testTagCreationIsCaseInsensitive() {
        let model = makeModel()
        model.ensureTag(named: "Conference")
        model.ensureTag(named: "conference")
        XCTAssertEqual(model.tags.count, 1)
    }

    func testDeletingTagRemovesItFromCards() {
        let model = makeModel()
        let saved = model.add(card())
        model.deleteTag(named: "Conference")
        XCTAssertTrue(model.card(id: saved.id)?.tags.isEmpty ?? false)
    }

    func testSetTagsReplacesAndDeduplicates() {
        let model = makeModel()
        let saved = model.add(card())
        model.setTags(["A", "A", " B "], on: saved)
        XCTAssertEqual(model.card(id: saved.id)?.tags, ["A", "B"])
    }

    func testPersistenceRoundTripThroughFileStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = CardLibraryModel(store: FileCardStore(root: root))
        let saved = first.add(card())

        // A new model simulates "kill the app and relaunch" (T18).
        let second = CardLibraryModel(store: FileCardStore(root: root))
        XCTAssertEqual(second.cards.count, 1)
        XCTAssertEqual(second.card(id: saved.id)?.name, "朱宏明")
    }
}
