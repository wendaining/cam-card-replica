import AVFoundation
import Foundation

enum CameraPermissionStatus: String, Sendable {
    case authorized
    case denied
    case restricted
    case notDetermined

    var canUseCamera: Bool { self == .authorized }
}

/// T03's test seam: the UI tests inject a fixed status instead of trying to
/// drive the real system prompt (which the simulator cannot even show for a
/// camera that does not exist).
protocol CameraPermissionProviding: Sendable {
    func currentStatus() -> CameraPermissionStatus
    func requestAccess() async -> CameraPermissionStatus
}

struct SystemCameraPermission: CameraPermissionProviding {
    func currentStatus() -> CameraPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func requestAccess() async -> CameraPermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }
}

/// Deterministic double used by UI tests and SwiftUI previews.
struct StubCameraPermission: CameraPermissionProviding {
    let status: CameraPermissionStatus

    func currentStatus() -> CameraPermissionStatus { status }
    func requestAccess() async -> CameraPermissionStatus { status }
}
