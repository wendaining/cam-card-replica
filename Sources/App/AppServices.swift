import Foundation
import Observation

/// Composition root: the only place that decides "real" vs "test" dependencies.
@MainActor
@Observable
final class AppServices {
    let library: CardLibraryModel
    let recognizer: any TextRecognizing
    let detector: any CardDetecting
    let corrector: any ImageCorrecting
    let exporter: any ContactExporting
    let parser: any FieldParsing
    let permission: any CameraPermissionProviding
    let fixtures: FixtureProvider?
    let configuration: UITestConfiguration

    init(
        library: CardLibraryModel,
        recognizer: any TextRecognizing,
        detector: any CardDetecting,
        corrector: any ImageCorrecting,
        exporter: any ContactExporting,
        parser: any FieldParsing,
        permission: any CameraPermissionProviding,
        fixtures: FixtureProvider?,
        configuration: UITestConfiguration
    ) {
        self.library = library
        self.recognizer = recognizer
        self.detector = detector
        self.corrector = corrector
        self.exporter = exporter
        self.parser = parser
        self.permission = permission
        self.fixtures = fixtures
        self.configuration = configuration
    }

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppServices {
        let configuration = UITestConfiguration.fromProcess(arguments)
        let store: CardStore
        if configuration.isUITesting || configuration.seedDemoData {
            // T01 needs the empty state; T12+ need seed data. Both are in-memory
            // so tests never touch the real store.
            let library = configuration.seedDemoData
                ? CardLibrary(cards: DemoData.cards, tags: DemoData.tags)
                : CardLibrary.empty
            store = InMemoryCardStore(library: library)
        } else {
            store = FileCardStore()
        }

        let permission: any CameraPermissionProviding = configuration.simulatedCameraPermission
            .map { StubCameraPermission(status: $0) }
            ?? SystemCameraPermission()

        return AppServices(
            library: CardLibraryModel(store: store),
            recognizer: VisionTextRecognizer(),
            detector: VisionCardDetector(),
            corrector: CoreImageCardCorrector(),
            exporter: ContactsExporter(),
            parser: HeuristicFieldParser(),
            permission: permission,
            fixtures: configuration.useFixtureCamera ? FixtureProvider.bundled() : nil,
            configuration: configuration
        )
    }
}
