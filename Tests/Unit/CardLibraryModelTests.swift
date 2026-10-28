@testable import CamCardReplica
import XCTest

@MainActor
final class CardLibraryModelTests: XCTestCase {
    func testAddFailureDoesNotPublishCardOrTags() throws {
        let store = FailingCardStore()
        store.failsSave = true
        let model = CardLibraryModel(store: store)
        XCTAssertThrowsError(try model.add(card()))
        XCTAssertTrue(model.cards.isEmpty)
        XCTAssertTrue(model.tags.isEmpty)
        XCTAssertTrue(store.library.cards.isEmpty)
        XCTAssertNotNil(model.lastErrorMessage)
    }

    func testUpdateFailurePreservesCommittedFields() throws {
        let store = FailingCardStore()
        let model = CardLibraryModel(store: store)
        let saved = try model.add(card())
        store.failsSave = true
        var edited = saved
        edited.name = "Lost update"
        XCTAssertThrowsError(try model.update(edited))
        XCTAssertEqual(model.card(id: saved.id)?.name, saved.name)
        XCTAssertEqual(CardLibraryModel(store: store).card(id: saved.id)?.name, saved.name)
    }

    func testDeleteFailureKeepsRecordAndBothImages() throws {
        let store = FailingCardStore()
        var saved = card()
        saved.originalImageID = "original"
        saved.processedImageID = "processed"
        store.library = CardLibrary(cards: [saved])
        store.images = ["original": Data([1]), "processed": Data([2])]
        store.failsSave = true
        let model = CardLibraryModel(store: store)
        XCTAssertThrowsError(try model.delete(saved))
        XCTAssertNotNil(model.card(id: saved.id))
        let reloaded = CardLibraryModel(store: store)
        XCTAssertEqual(reloaded.imageData(for: saved, original: true), Data([1]))
        XCTAssertEqual(reloaded.imageData(for: saved), Data([2]))
    }

    func testJSONFailureRollsBackNewImages() throws {
        let store = FailingCardStore()
        store.failsSave = true
        let model = CardLibraryModel(store: store)
        XCTAssertThrowsError(try model.add(card(), originalImageData: Data([1]), processedImageData: Data([2])))
        XCTAssertTrue(store.images.isEmpty)
        XCTAssertTrue(model.cards.isEmpty)
        store.failsSave = false
        let saved = try model.add(card(), originalImageData: Data([1]), processedImageData: Data([2]))
        XCTAssertEqual(model.imageData(for: saved, original: true), Data([1]))
        XCTAssertNil(model.lastErrorMessage)
    }

    func testTagCaseIsCanonicalAcrossSaveFilterDeleteAndReload() throws {
        let store = InMemoryCardStore()
        let model = CardLibraryModel(store: store)
        try model.ensureTag(named: "Conference")
        let saved = try model.add(BusinessCard(name: "Review", tags: [" conference ", "CONFERENCE"]))
        XCTAssertEqual(saved.tags, ["Conference"])
        XCTAssertEqual(model.cards(matching: "", tag: "conference").count, 1)
        try model.deleteTag(named: "cONFERENCE")
        let reloaded = CardLibraryModel(store: store)
        XCTAssertTrue(reloaded.tags.isEmpty)
        XCTAssertEqual(reloaded.card(id: saved.id)?.tags, [])
    }

    func testTagDraftChangesAreAtomicWithCardSave() throws {
        let store = FailingCardStore()
        let model = CardLibraryModel(store: store)
        let saved = try model.add(card())
        let other = try model.add(card(name: "Other Contact"))
        var draft = CardDraft(card: saved)
        draft.deleteTag(named: "Conference")
        draft.createTag(named: "Customer", knownTags: model.tags)
        XCTAssertEqual(model.card(id: saved.id)?.tags, ["Conference"])
        store.failsSave = true
        XCTAssertThrowsError(try model.update(draft.makeCard(id: saved.id), deletingTags: draft.deletedTags))
        XCTAssertEqual(model.card(id: saved.id)?.tags, ["Conference"])
        store.failsSave = false
        try model.update(draft.makeCard(id: saved.id), deletingTags: draft.deletedTags)
        XCTAssertEqual(model.tags.map(\.name), ["Customer"])
        XCTAssertEqual(CardLibraryModel(store: store).card(id: saved.id)?.tags, ["Customer"])
        XCTAssertEqual(model.card(id: other.id)?.tags, [])
    }

    func testUnreadableLibraryIsNotOverwrittenByNewRecord() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileCardStore(root: root)
        let path = root.appendingPathComponent("library.json")
        let damaged = Data("unreadable library".utf8)
        try damaged.write(to: path)
        let model = CardLibraryModel(store: store)
        XCTAssertThrowsError(try model.add(card()))
        XCTAssertEqual(try Data(contentsOf: path), damaged)
        XCTAssertTrue(model.cards.isEmpty)
    }

    func testSecondImageFailureRollsBackFirstImage() throws {
        let store = FailingCardStore()
        store.failingImageWrite = 2
        let model = CardLibraryModel(store: store)
        XCTAssertThrowsError(try model.add(card(), originalImageData: Data([1]), processedImageData: Data([2])))
        XCTAssertTrue(store.images.isEmpty)
        XCTAssertTrue(store.library.cards.isEmpty)
    }

    func testEditedFieldsNotesTagsAndBothImagesSurviveFileReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = CardLibraryModel(store: FileCardStore(root: root))
        var saved = try model.add(card(), originalImageData: Data([1]), processedImageData: Data([2]))
        saved.company = "Edited Company"
        saved.notes = "Review note"
        saved.tags = ["Customer"]
        try model.update(saved)
        let reloaded = CardLibraryModel(store: FileCardStore(root: root))
        let restored = try XCTUnwrap(reloaded.card(id: saved.id))
        XCTAssertEqual(restored.company, "Edited Company")
        XCTAssertEqual(restored.notes, "Review note")
        XCTAssertEqual(restored.tags, ["Customer"])
        XCTAssertEqual(reloaded.imageData(for: restored, original: true), Data([1]))
        XCTAssertEqual(reloaded.imageData(for: restored), Data([2]))
    }

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

    func testAddPersistsImmediately() throws {
        let store = InMemoryCardStore()
        let model = CardLibraryModel(store: store)
        try model.add(card())
        XCTAssertEqual(model.cards.count, 1)
        XCTAssertEqual(store.library.cards.count, 1, "add must write through the store (T18)")
    }

    func testUpdateChangesFields() throws {
        let model = makeModel()
        let saved = try model.add(card())
        var edited = saved
        edited.name = "朱宏明（教授）"
        try model.update(edited)
        XCTAssertEqual(model.card(id: saved.id)?.name, "朱宏明（教授）")
    }

    func testDeleteRemovesCardAndImages() throws {
        let store = InMemoryCardStore()
        let model = CardLibraryModel(store: store)
        let imageID = try model.saveImage(Data([0x01]))
        var saved = card()
        saved.originalImageID = imageID
        let stored = try model.add(saved)

        try model.delete(stored)
        XCTAssertTrue(model.cards.isEmpty)
        XCTAssertNil(store.readImage(id: imageID), "images must not leak after delete")
    }

    func testSearchAndTagFilter() throws {
        let model = makeModel()
        try model.add(BusinessCard(name: "朱宏明", company: "同济大学", tags: ["Professor"]))
        try model.add(BusinessCard(name: "David Chen", company: "ABC Technologies", tags: ["Customer"]))

        XCTAssertEqual(model.cards(matching: "David", tag: nil).count, 1)
        XCTAssertEqual(model.cards(matching: "", tag: "Professor").count, 1)
        XCTAssertEqual(model.cards(matching: "同济", tag: "Customer").count, 0)
    }

    func testTagCreationIsCaseInsensitive() throws {
        let model = makeModel()
        try model.ensureTag(named: "Conference")
        try model.ensureTag(named: "conference")
        XCTAssertEqual(model.tags.count, 1)
    }

    func testDeletingTagRemovesItFromCards() throws {
        let model = makeModel()
        let saved = try model.add(card())
        try model.deleteTag(named: "Conference")
        XCTAssertTrue(model.card(id: saved.id)?.tags.isEmpty ?? false)
    }

    func testSetTagsReplacesAndDeduplicates() throws {
        let model = makeModel()
        let saved = try model.add(card())
        try model.setTags(["A", "A", " B "], on: saved)
        XCTAssertEqual(model.card(id: saved.id)?.tags, ["A", "B"])
    }

    func testPersistenceRoundTripThroughFileStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = CardLibraryModel(store: FileCardStore(root: root))
        let saved = try first.add(card())

        // A new model simulates "kill the app and relaunch" (T18).
        let second = CardLibraryModel(store: FileCardStore(root: root))
        XCTAssertEqual(second.cards.count, 1)
        XCTAssertEqual(second.card(id: saved.id)?.name, "朱宏明")
    }
}
