import Foundation

enum ContactExportError: LocalizedError {
    case accessDenied
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "没有通讯录写入权限，请在「设置」中开启。"
        case .encodingFailed: return "生成 vCard 失败。"
        }
    }
}

/// spec 十三 / T19.
protocol ContactExporting: Sendable {
    /// RFC 6350 vCard data, shareable through the system share sheet.
    func vCard(for card: BusinessCard) throws -> Data
    /// Writes into the system Contacts database.
    func saveToContacts(_ card: BusinessCard) async throws
}
