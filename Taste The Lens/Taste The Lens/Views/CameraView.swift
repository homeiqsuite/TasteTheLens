import SwiftUI
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "CameraView")

struct CameraView: View {
    @State var cameraManager = CameraManager()
    @State private var isPulsing = false
    var onPhotoCaptured: (UIImage) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            } else {
                permissionDeniedView
            }

            // UI overlay
            VStack {
                Spacer()

                // Hint text
                Text("Point at anything. Art, architecture, a sunset. Tap to taste.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(isPulsing ? 1 : 0.5)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isPulsing)

                Spacer().frame(height: 24)

                ShutterButton {
                    capturePhoto()
                }

                Spacer().frame(height: 40)
            }
        }
        .task {
            logger.info("Checking camera permission...")
            await cameraManager.checkPermission()
            logger.info("Permission granted: \(cameraManager.permissionGranted)")
            cameraManager.startSession()
            logger.info("Camera session started")
        }
        .onAppear { isPulsing = true }
        .onDisappear { cameraManager.stopSession() }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            Text("Camera access is required")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Text("Open Settings to grant camera permission.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func capturePhoto() {
        logger.info("Shutter tapped — capturing photo")
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task {
            do {
                let image = try await cameraManager.capturePhoto()
                logger.info("Photo captured successfully: \(image.size.width)x\(image.size.height)")
                cameraManager.stopSession()
                onPhotoCaptured(image)
            } catch {
                logger.error("Photo capture failed: \(error.localizedDescription)")
            }
        }
    }
}
