import SwiftUI

@Observable @MainActor
final class FusionModeState {
    var isActive = false
    var capturedImages: [UIImage] = []
    var showDismissConfirmation = false

    private var lastCaptureTime: Date?
    private let minimumCaptureInterval: TimeInterval = 0.5

    var shotCount: Int { capturedImages.count }
    var canFuse: Bool { capturedImages.count >= 2 }
    var canCapture: Bool { capturedImages.count < 3 }
    var shotLabel: String { "\(capturedImages.count)/3" }

    func addImage(_ image: UIImage) {
        guard canCapture else { return }
        if let last = lastCaptureTime,
           Date().timeIntervalSince(last) < minimumCaptureInterval {
            return
        }
        capturedImages.append(image)
        lastCaptureTime = Date()
    }

    func removeImage(at index: Int) {
        guard capturedImages.indices.contains(index) else { return }
        capturedImages.remove(at: index)
    }

    func reset() {
        isActive = false
        capturedImages = []
        showDismissConfirmation = false
        lastCaptureTime = nil
    }
}
