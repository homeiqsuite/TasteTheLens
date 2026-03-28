import SwiftUI
import PhotosUI
import os

private let logger = makeLogger(category: "CameraView")

struct CameraView: View {
    @State var cameraManager = CameraManager()
    @State private var isPulsing = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var fusionState = FusionModeState()
    @State private var showFusionTooltip = false
    @AppStorage("selectedChef") private var selectedChef = "default"
    @AppStorage("hasSeenFusionTooltip") private var hasSeenFusionTooltip = false

    var onPhotoCaptured: (UIImage) -> Void
    var onFusionPhotoCaptured: (([UIImage]) -> Void)?
    var onChefTapped: () -> Void

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

                // Fusion tray (above hint text when active)
                if fusionState.isActive {
                    FusionTrayView(
                        images: fusionState.capturedImages,
                        onRemove: { index in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                fusionState.removeImage(at: index)
                            }
                        },
                        onFuse: {
                            fuseDish()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Hint text
                Group {
                    if fusionState.isActive {
                        Text("Fusion Mode — capture 2-3 shots")
                            .foregroundStyle(Theme.gold)
                    } else {
                        Text("Point at anything. Art, architecture, a sunset. Tap to taste.")
                            .foregroundStyle(Theme.darkTextSecondary)
                            .opacity(isPulsing ? 1 : 0.5)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isPulsing)
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.3), value: fusionState.isActive)

                Spacer().frame(height: 24)

                // Fusion tooltip (positioned above shutter)
                if showFusionTooltip {
                    FusionTooltip {
                        showFusionTooltip = false
                        hasSeenFusionTooltip = true
                    }
                    .transition(.opacity)
                    .padding(.bottom, 4)
                }

                HStack {
                    // Photo library picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Theme.darkTextSecondary)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .disabled(fusionState.isActive)
                    .opacity(fusionState.isActive ? 0.3 : 1)

                    Spacer()

                    ShutterButton(
                        action: {
                            fusionState.isActive ? captureFusionShot() : capturePhoto()
                        },
                        onLongPress: {
                            toggleFusionMode()
                        },
                        isFusionMode: fusionState.isActive,
                        shotLabel: fusionState.isActive ? fusionState.shotLabel : nil
                    )

                    Spacer()

                    // Chef picker
                    Button {
                        onChefTapped()
                    } label: {
                        let chef = ChefPersonality(rawValue: selectedChef) ?? .defaultChef
                        Image(systemName: chef.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Theme.darkTextSecondary)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 40)
            }
            .animation(.easeInOut(duration: 0.35), value: fusionState.isActive)
        }
        .task {
            logger.info("Checking camera permission...")
            await cameraManager.checkPermission()
            logger.info("Permission granted: \(cameraManager.permissionGranted)")
            cameraManager.startSession()
            logger.info("Camera session started")
        }
        .onAppear {
            isPulsing = true
            // Show fusion tooltip on first camera open
            if !hasSeenFusionTooltip {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { showFusionTooltip = true }
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
            if fusionState.isActive {
                fusionState.reset()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    logger.info("Photo picked from library: \(image.size.width)x\(image.size.height)")
                    cameraManager.stopSession()
                    onPhotoCaptured(image)
                } else {
                    logger.error("Failed to load image from PhotosPicker")
                }
                selectedPhotoItem = nil
            }
        }
        .alert("Discard Fusion Shots?", isPresented: $fusionState.showDismissConfirmation) {
            Button("Discard", role: .destructive) {
                withAnimation {
                    fusionState.reset()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(fusionState.shotCount) photo\(fusionState.shotCount == 1 ? "" : "s") captured. Discard them?")
        }
    }

    // MARK: - Permission Denied

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.darkTextHint)
            Text("Camera access is required")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.darkTextSecondary)
            Text("Open Settings to grant camera permission.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextTertiary)
        }
    }

    // MARK: - Single-Shot Capture

    private func capturePhoto() {
        logger.info("Shutter tapped — capturing photo")
        HapticManager.medium()

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

    // MARK: - Fusion Mode

    private func toggleFusionMode() {
        if fusionState.isActive {
            // Deactivate — confirm if shots exist
            if fusionState.shotCount > 0 {
                fusionState.showDismissConfirmation = true
            } else {
                withAnimation {
                    fusionState.reset()
                }
            }
        } else {
            // Activate fusion mode
            logger.info("Entering Fusion Mode")
            HapticManager.heavy()
            withAnimation {
                fusionState.isActive = true
            }
            // Dismiss tooltip if still visible
            if showFusionTooltip {
                showFusionTooltip = false
                hasSeenFusionTooltip = true
            }
        }
    }

    private func captureFusionShot() {
        guard fusionState.canCapture else {
            logger.info("Fusion mode — max 3 shots reached")
            return
        }

        logger.info("Fusion shutter tapped — capturing shot \(fusionState.shotCount + 1)/3")
        HapticManager.medium()

        Task {
            do {
                let image = try await cameraManager.capturePhoto()
                logger.info("Fusion shot captured: \(image.size.width)x\(image.size.height)")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    fusionState.addImage(image)
                }
                // Camera stays running — do NOT stop session
            } catch {
                logger.error("Fusion photo capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func fuseDish() {
        guard fusionState.canFuse else { return }
        logger.info("Fusing \(fusionState.shotCount) images into recipe")
        cameraManager.stopSession()
        let images = fusionState.capturedImages
        fusionState.reset()
        onFusionPhotoCaptured?(images)
    }
}
