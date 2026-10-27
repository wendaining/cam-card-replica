import Foundation

/// Accessibility identifiers shared by the app and the UI tests.
/// Keeping them in one place is what stops the tests from silently rotting when
/// a label changes.
enum A11y {
    // Card list
    static let cardList = "card-list"
    static let emptyState = "empty-state"
    static let scanButton = "scan-button"
    static let searchField = "search-field"
    static let tagFilter = "tag-filter"

    // Scanner / crop
    static let scannerView = "scanner-view"
    static let shutterButton = "shutter-button"
    static let importButton = "import-button"
    static let cameraDeniedMessage = "camera-denied-message"
    static let cropView = "crop-view"
    static let cropConfirm = "crop-confirm"
    static let cropRetake = "crop-retake"

    // Recognition / review
    static let processingIndicator = "processing-indicator"
    static let reviewView = "review-view"
    static let reviewSave = "review-save"
    static let reviewCancel = "review-cancel"
    static let rawTextButton = "raw-text-button"

    // Detail
    static let detailView = "detail-view"
    static let detailEdit = "detail-edit"
    static let detailDelete = "detail-delete"
    static let detailExport = "detail-export"
    static let detailEditSave = "detail-edit-save"

    static func field(_ field: CardField) -> String {
        "field-\(field.rawValue)"
    }

    static func cardRow(_ id: UUID) -> String {
        "card-row-\(id.uuidString)"
    }

    static func tagChip(_ name: String) -> String {
        "tag-chip-\(name)"
    }
}
