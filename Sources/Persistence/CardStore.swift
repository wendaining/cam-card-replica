import Foundation

enum CardStoreError: LocalizedError {
    case corruptedLibrary(underlying: Error)
    case writeFailed(underlying: Error)
    case imageNotFound(String)

    var errorDescription: String? {
        switch self {
        case .corruptedLibrary: "名片数据损坏，无法读取。"
        case .writeFailed: "保存失败，请检查存储空间后重试。"
        case .imageNotFound: "名片图片不存在。"
        }
    }
}

/// Storage contract. The app talks to this protocol only, so UI tests can run
/// against an in-memory implementation and never touch the filesystem.
protocol CardStore: AnyObject {
    func load() throws -> CardLibrary
    func save(_ library: CardLibrary) throws

    func writeImage(_ data: Data, id: String) throws
    func readImage(id: String) -> Data?
    func deleteImage(id: String)
}
