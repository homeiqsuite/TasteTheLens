import SwiftUI

@Observable @MainActor
final class FusionModeState {
    var isActive = false
    var capturedImages: [UIImage] = []
    var showDismissConfirmation = false

    var shotCount: Int { capturedImages.count }
    var canFuse: Bool { capturedImages.count >= 2 }
    var canCapture: Bool { capturedImages.count < 3 }
    var shotLabel: String { "\(capturedImages.count)/3" }

    func addImage(_ image: UIImage) {
        guard canCapture else { return }
        capturedImages.append(image)
    }

    func removeImage(at index: Int) {
        guard capturedImages.indices.contains(index) else { return }
        capturedImages.remove(at: index)
    }

    func reset() {
        isActive = false
        capturedImages = []
        showDismissConfirmation = false
    }
}
