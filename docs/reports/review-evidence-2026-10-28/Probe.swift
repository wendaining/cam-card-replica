import Foundation
import CoreGraphics
import ImageIO
import Vision

final class FailingStore: CardStore {
 var library = CardLibrary.empty
 var images: [String: Data] = [:]
 func load() throws -> CardLibrary { library }
 func save(_ library: CardLibrary) throws { throw NSError(domain: "review disk full", code: 28) }
 func writeImage(_ data: Data, id: String) throws { images[id] = data }
 func readImage(id: String) -> Data? { images[id] }
 func deleteImage(id: String) { images.removeValue(forKey: id) }
}
@main struct Probe {
 @MainActor static func main() throws {
  let failureStore = FailingStore()
  let services = AppServices(library: CardLibraryModel(store: failureStore), recognizer: VisionTextRecognizer(), detector: VisionCardDetector(), corrector: CoreImageCardCorrector(), exporter: ContactsExporter(), parser: HeuristicFieldParser(), permission: StubCameraPermission(status: .denied), fixtures: nil, configuration: .production)
  let flow = ScanFlowModel(services: services); flow.draft.name = "unsaved"
  print("FAILED_SAVE returned=\(flow.save() != nil) flowError=\(flow.errorMessage ?? "nil") libraryError=\(services.library.lastErrorMessage ?? "nil") inMemory=\(services.library.cards.count) disk=\(failureStore.library.cards.count)")
  let deleteStore = FailingStore()
  let doomed = BusinessCard(name: "delete failure", originalImageID: "original")
  deleteStore.library = CardLibrary(cards: [doomed])
  deleteStore.images["original"] = Data([1,2,3])
  let deleteModel = CardLibraryModel(store: deleteStore)
  deleteModel.delete(doomed)
  print("FAILED_DELETE diskCards=\(deleteStore.library.cards.count) imageExists=\(deleteStore.images["original"] != nil)")
  let tags = CardLibraryModel(store: InMemoryCardStore())
  tags.ensureTag(named: "Conference")
  tags.add(BusinessCard(name: "tag case", tags: ["conference"]))
  print("TAG_CASE library=\(tags.tags) card=\(tags.cards[0].tags) filtered=\(tags.cards(matching: "", tag: "Conference").count)")
  let root = URL(fileURLWithPath: "/tmp/camcard-review/fresh-" + UUID().uuidString)
  let model = CardLibraryModel(store: FileCardStore(root: root))
  let saved = model.add(BusinessCard(name: "Review Fixture"))
  print("FIRST_SAVE inMemory=\(model.cards.count) error=\(model.lastErrorMessage ?? "nil") reloaded=\(CardLibraryModel(store: FileCardStore(root: root)).cards.count) returned=\(saved.name)")
  for texts in [["Jordan Lee", "Independent professional", "Email: jordan@demo.example"], ["Jordan Lee", "Mobile: 13800001234 Tel: 021-60001234 Fax: 021-60005678"], ["Jordan Lee", "Designer", "Email: user13800001234@demo.example"], ["Jordan Lee", "Tel: 021-60001234", "www.example.com.hk"]] {
   let p = HeuristicFieldParser().parse(lines: texts)
   print("PARSE \(texts) => name=\(p.name?.value ?? "nil") company=\(p.company?.value ?? "nil") title=\(p.jobTitle?.value ?? "nil") site=\(p.website?.value ?? "nil") phones=\(p.phones)")
  }
  let req = VNDetectRectanglesRequest(); req.minimumAspectRatio = 1.25; req.maximumAspectRatio = 2.4
  print("VISION ratio after setter: \(req.minimumAspectRatio),\(req.maximumAspectRatio)")
  for file in ["zh-01-photo.jpg", "bi-14-photo-occluded.jpg"] {
   let url = URL(fileURLWithPath: "Resources/Fixtures/" + file)
   let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
   let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
   do { print("DETECT \(file): \(String(describing: try VisionCardDetector().detectCard(in: image, orientation: .up)))") } catch { print("DETECT \(file) error: \(error)") }
  }
 }
}
