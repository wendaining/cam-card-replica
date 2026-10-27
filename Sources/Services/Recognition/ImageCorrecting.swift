import CoreGraphics
import Foundation

protocol ImageCorrecting: Sendable {
    /// Applies the perspective transform described by `quad`.
    func correct(_ image: CGImage, quad: Quad) throws -> CGImage
}

enum ImageCorrectionError: LocalizedError {
    case renderFailed
    case invalidQuad

    var errorDescription: String? {
        switch self {
        case .renderFailed: return "图片校正失败，请重新拍摄。"
        case .invalidQuad: return "未识别到有效的名片区域。"
        }
    }
}
