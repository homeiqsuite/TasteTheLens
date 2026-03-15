@preconcurrency import AVFoundation
import UIKit

@Observable
final class CameraManager: NSObject {
    var capturedImage: UIImage?
    var isSessionRunning = false
    var permissionGranted = false

    // Accessed from sessionQueue — marked nonisolated(unsafe) for cross-isolation access.
    // Safe because all session operations are serialized on sessionQueue.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.tastethelens.camera")
    private var continuation: CheckedContinuation<UIImage, Error>?

    override init() {
        super.init()
    }

    func checkPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            permissionGranted = false
        }
    }

    func startSession() {
        guard permissionGranted else { return }
        sessionQueue.async { [self] in
            self.configureSession()
        }
    }

    func stopSession() {
        sessionQueue.async { [self] in
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            let photoOutput = self.photoOutput
            sessionQueue.async { [self] in
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private nonisolated func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
        session.startRunning()

        Task { @MainActor [weak self] in
            self?.isSessionRunning = true
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.continuation?.resume(throwing: error)
                self.continuation = nil
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                self.continuation?.resume(throwing: CameraError.captureFailure)
                self.continuation = nil
                return
            }

            self.capturedImage = image
            self.continuation?.resume(returning: image)
            self.continuation = nil
        }
    }
}

enum CameraError: LocalizedError {
    case captureFailure
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .captureFailure: return "Failed to capture photo. Please try again."
        case .permissionDenied: return "Camera access is required to use Taste The Lens."
        }
    }
}
