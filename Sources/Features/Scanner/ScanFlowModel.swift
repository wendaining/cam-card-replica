import CoreGraphics
import Foundation
import ImageIO
import Observation

/// Drives capture -> detect -> correct -> OCR -> parse -> review.
///
/// The stage enum is the contract the UI renders, and every transition is
/// covered by a UI test (T04–T07, T20).
@MainActor
@Observable
final class ScanFlowModel {
    enum Stage: Equatable {
        case capture
        /// "Is this shot usable?" — the explicit preview step before cropping.
        case preview
        case crop
        case processing
        case review
    }

    private let services: AppServices
    private var fixtureIndex = 0
    private var operationID = UUID()
    private var detectionTask: Task<(Quad, TimeInterval), Never>?
    private var recognitionTask: Task<RecognitionOutput, Error>?

    private struct RecognitionOutput: Sendable {
        var image: CGImage
        var ocr: OCRResult
        var parsed: ParsedCard
        var timings: [String: TimeInterval]
    }

    private(set) var stage: Stage = .capture
    private(set) var capturedImage: CGImage?
    private(set) var correctedImage: CGImage?
    private(set) var parsed: ParsedCard = .empty
    private(set) var ocr: OCRResult?
    private(set) var errorMessage: String?
    private(set) var lowConfidenceFields: Set<CardField> = []
    private(set) var timings: [String: TimeInterval] = [:]

    var quad: Quad = .fullFrame
    var draft = CardDraft()

    init(services: AppServices) {
        self.services = services
    }

    // MARK: - Capture

    /// Entry point from the camera or the photo picker.
    func handle(image: CGImage, orientation: CGImagePropertyOrientation = .up) {
        // Bake the orientation in first: everything downstream (detection,
        // perspective correction, OCR) then shares one coordinate space.
        retake()
        let upright = ImageCoding.applyingOrientation(image, orientation)
        capturedImage = upright
        errorMessage = nil
        quad = .fullFrame
        stage = .preview
    }

    /// Accepts the shot: run boundary detection, then show the crop screen.
    func confirmPreview() async {
        guard let image = capturedImage, stage == .preview else { return }
        let token = UUID()
        operationID = token
        stage = .processing
        let detector = services.detector
        let task = Task.detached(priority: .userInitiated) {
            let started = CFAbsoluteTimeGetCurrent()
            let result = (try? detector.detectCard(in: image, orientation: .up)) ?? .fullFrame
            return (result, CFAbsoluteTimeGetCurrent() - started)
        }
        detectionTask = task
        let (result, duration) = await task.value
        guard operationID == token, !Task.isCancelled else { return }
        detectionTask = nil
        quad = result
        timings["detect"] = duration
        stage = .crop
    }

    /// Deterministic path used by UI tests and simulator runs without a camera.
    func captureFixture() {
        guard let fixtures = services.fixtures else {
            errorMessage = "测试图片不可用。"
            return
        }
        if let pinned = services.configuration.fixtureName,
           let image = fixtures.image(named: pinned) {
            handle(image: image)
            return
        }
        guard let fixture = fixtures.image(at: fixtureIndex) else {
            errorMessage = "测试图片不可用。"
            return
        }
        fixtureIndex += 1
        handle(image: fixture.image)
    }

    func report(error: String) {
        errorMessage = error
    }

    func retake() {
        operationID = UUID()
        detectionTask?.cancel()
        recognitionTask?.cancel()
        detectionTask = nil
        recognitionTask = nil
        draft = CardDraft()
        lowConfidenceFields = []
        timings = [:]
        capturedImage = nil
        correctedImage = nil
        ocr = nil
        parsed = .empty
        quad = .fullFrame
        errorMessage = nil
        stage = .capture
    }

    // MARK: - Recognition

    func confirmCrop() async {
        guard let image = capturedImage, stage == .crop else { return }
        let token = UUID()
        operationID = token
        stage = .processing
        errorMessage = nil
        let corrector = services.corrector
        let recognizer = services.recognizer
        let parser = services.parser
        let quad = quad
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            var durations: [String: TimeInterval] = [:]
            let correctionStarted = CFAbsoluteTimeGetCurrent()
            let corrected = (try? corrector.correct(image, quad: quad)) ?? image
            durations["correct"] = CFAbsoluteTimeGetCurrent() - correctionStarted
            try Task.checkCancellation()
            let ocrStarted = CFAbsoluteTimeGetCurrent()
            let result = try recognizer.recognize(image: corrected, orientation: .up)
            durations["ocr"] = CFAbsoluteTimeGetCurrent() - ocrStarted
            try Task.checkCancellation()
            let parseStarted = CFAbsoluteTimeGetCurrent()
            let parsed = parser.parse(result)
            durations["parse"] = CFAbsoluteTimeGetCurrent() - parseStarted
            return RecognitionOutput(image: corrected, ocr: result, parsed: parsed, timings: durations)
        }
        recognitionTask = task
        do {
            let result = try await task.value
            guard operationID == token, !Task.isCancelled else { return }
            recognitionTask = nil
            correctedImage = result.image
            ocr = result.ocr
            parsed = result.parsed
            draft = CardDraft(parsed: result.parsed, rawText: result.ocr.rawText, ocr: result.ocr)
            lowConfidenceFields = Self.lowConfidenceFields(in: result.parsed)
            timings.merge(result.timings) { _, latest in latest }
            stage = .review
        } catch {
            guard operationID == token, !Task.isCancelled else { return }
            recognitionTask = nil
            errorMessage = "识别失败：" + error.localizedDescription
            stage = .crop
        }
    }

    // MARK: - Save

    func save() -> BusinessCard? {
        guard draft.canSave else {
            errorMessage = "请至少填写姓名。"
            return nil
        }
        do {
            let originalData = capturedImage.flatMap { ImageCoding.jpegData(from: $0) }
            let processedData = correctedImage.flatMap { ImageCoding.jpegData(from: $0) }
            let card = draft.makeCard(rawText: ocr?.rawText)
            return try services.library.add(
                card,
                originalImageData: originalData,
                processedImageData: processedData,
                deletingTags: draft.deletedTags
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Helpers

    nonisolated static func lowConfidenceFields(in parsed: ParsedCard, threshold: Double = 0.78) -> Set<CardField> {
        var fields = Set<CardField>()
        if let name = parsed.name, name.confidence < threshold {
            fields.insert(.name)
        }
        if let company = parsed.company, company.confidence < threshold {
            fields.insert(.company)
        }
        if let title = parsed.jobTitle, title.confidence < threshold {
            fields.insert(.jobTitle)
        }
        if let dept = parsed.department, dept.confidence < threshold {
            fields.insert(.department)
        }
        if let website = parsed.website, website.confidence < threshold {
            fields.insert(.website)
        }
        if let address = parsed.address, address.confidence < threshold {
            fields.insert(.address)
        }
        if let email = parsed.emails.first, email.confidence < threshold {
            fields.insert(.email)
        }
        for phone in parsed.phones where phone.value.confidence < threshold {
            switch phone.kind {
            case .mobile: fields.insert(.mobile)
            case .office: fields.insert(.office)
            case .fax: fields.insert(.fax)
            }
        }
        return fields
    }
}
