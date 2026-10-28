import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The share item is a value of the current saved card, never a cached URL.
struct VCardDocument: Transferable {
    let card: BusinessCard
    var exporter: any ContactExporting = ContactsExporter()

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .vCard) { document in
            try SentTransferredFile(document.writeFile())
        }
    }

    func writeFile(in directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let data = try exporter.vCard(for: card)
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(card.id.uuidString).vcf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
}
