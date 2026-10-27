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
        case crop
        case processing
        case review
    }

    private let services: AppServices
    private var fixtureIndex = 0

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
        capturedImage = image
        errorMessage = nil
        stage = .crop
        let started = CFAbsoluteTimeGetCurrent()
        do {
            quad = try services.detector.detectCard(in: image, orientation: orientation) ?? .fullFrame
        } catch {
            quad = .fullFrame
        }
        timings["detect"] = CFAbsoluteTimeGetCurrent() - started
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
        guard let image = capturedImage else { return }
        stage = .processing
        errorMessage = nil

        let started = CFAbsoluteTimeGetCurrent()
        let corrected = (try? services.corrector.correct(image, quad: quad)) ?? image
        correctedImage = corrected
        timings["correct"] = CFAbsoluteTimeGetCurrent() - started

        do {
            let ocrStarted = CFAbsoluteTimeGetCurrent()
            let result = try services.recognizer.recognize(image: corrected, orientation: .up)
            timings["ocr"] = CFAbsoluteTimeGetCurrent() - ocrStarted
            ocr = result

            let parseStarted = CFAbsoluteTimeGetCurrent()
            let parsedResult = services.parser.parse(result)
            timings["parse"] = CFAbsoluteTimeGetCurrent() - parseStarted
            parsed = parsedResult
            draft = CardDraft(parsed: parsedResult, rawText: result.rawText)
            lowConfidenceFields = Self.lowConfidenceFields(in: parsedResult)

            stage = .review
        } catch {
            errorMessage = error.localizedDescription
            stage = .crop
        }
    }

    func cancelReview() {
        retake()
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
            let originalID = try originalData.map { try services.library.saveImage($0) }
            let processedID = try processedData.map { try services.library.saveImage($0) }
            let card = draft.makeCard(
                originalImageID: originalID,
                processedImageID: processedID,
                rawText: ocr?.rawText
            )
            return services.library.add(card)
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
