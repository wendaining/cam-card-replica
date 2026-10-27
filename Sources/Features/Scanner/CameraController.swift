import AVFoundation
import CoreGraphics
import Foundation
import Observation

/// Thin wrapper around `AVCaptureSession`.
///
/// Kept deliberately small: session lifecycle, one photo, no filters. The
/// preview layer lives in `CameraPreview` because UIKit types must not leak
/// into the model layer.
@MainActor
@Observable
final class CameraController {
    enum CameraError: LocalizedError {
        case unavailable
        case captureFailed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable: "相机不可用，请改用相册导入。"
            case .captureFailed(let reason): "拍摄失败：\(reason)"
            }
        }
    }

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.wendaining.camcard.camera.session")
    private let delegate = PhotoCaptureDelegate()
    private var isConfigured = false

    private(set) var isRunning = false
    private(set) var errorMessage: String?

    func start() {
        configureIfNeeded()
        guard isConfigured, !session.isRunning else { return }
        sessionQueue.async { [session] in
            session.startRunning()
        }
        isRunning = true
    }

    func stop() {
        guard session.isRunning else { return }
        sessionQueue.async { [session] in
            session.stopRunning()
        }
        isRunning = false
    }

    func capturePhoto() async throws -> Data {
        guard session.isRunning else { throw CameraError.unavailable }
        return try await delegate.capture(using: photoOutput)
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            errorMessage = CameraError.unavailable.localizedDescription
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
        isConfigured = true
    }
}

/// Delegate shim: `AVCapturePhotoCaptureDelegate` callbacks arrive on an
/// arbitrary queue, so they must not touch the main-actor controller.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private var continuation: CheckedContinuation<Data, Error>?
    private let lock = NSLock()

    func capture(using output: AVCapturePhotoOutput) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        if let error {
            continuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            continuation?.resume(returning: data)
        } else {
            continuation?.resume(throwing: CameraController.CameraError.captureFailed("空图像"))
        }
    }
}
