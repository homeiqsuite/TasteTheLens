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
    @State private var cameraError: String?
    @State private var showCameraError = false
    @State private var isCapturing = false
    @State private var currentTipIndex = 0
    @State private var tipRotationTask: Task<Void, Never>?
    private let cameraTips = [
        "Point at anything. Art, architecture, a sunset. Tap to taste.",
        "Good lighting helps AI see more detail",
        "Try interesting textures and colors",
    ]
    @AppStorage("selectedChef") private var selectedChef = "default"
    @AppStorage("hasSeenFusionTooltip") private var hasSeenFusionTooltip = false
    @AppStorage("hasSeenChefTooltip") private var hasSeenChefTooltip = false
    @State private var showChefTooltip = false

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
                        Text(cameraTips[currentTipIndex])
                            .foregroundStyle(Theme.darkTextSecondary)
                            .opacity(isPulsing ? 1 : 0.5)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isPulsing)
                            .id(currentTipIndex)
                            .transition(.opacity)
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.3), value: fusionState.isActive)

                Spacer().frame(height: 24)

                // Bottom controls: shutter + tooltips (overlay so shutter never moves)
                ZStack(alignment: .bottom) {
                    // Shutter + side buttons (fixed position, never moves)
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
                        .accessibilityLabel("Pick photo from library")
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
                        .accessibilityLabel(fusionState.isActive ? "Capture fusion shot, \(fusionState.shotLabel)" : "Capture photo")
                        .accessibilityHint(fusionState.isActive ? "Tap to capture. Long press to exit fusion mode." : "Tap to capture. Long press for fusion mode.")

                        Spacer()

                        // Chef picker
                        VStack(spacing: 4) {
                            if showChefTooltip {
                                CoachTooltip(
                                    text: "Your chef shapes recipe style and ingredients",
                                    icon: "person.crop.circle",
                                    pointer: .down
                                ) {
                                    showChefTooltip = false
                                    hasSeenChefTooltip = true
                                }
                                .transition(.opacity)
                            }

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
                    }
                    .padding(.horizontal, 32)

                    // Fusion tooltip (overlaid above shutter, doesn't affect layout)
                    VStack(spacing: 0) {
                        if showFusionTooltip {
                            FusionTooltip {
                                showFusionTooltip = false
                                hasSeenFusionTooltip = true
                            }
                            .transition(.opacity)
                            .padding(.bottom, 8)
                        }

                        Spacer()
                    }
                }
                .frame(height: 120)

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
            // Show chef tooltip on first camera open (independent of fusion tooltip)
            if !hasSeenChefTooltip {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { showChefTooltip = true }
                }
            }
            // Rotate camera tips every 6 seconds
            startTipRotation()
        }
        .onDisappear {
            tipRotationTask?.cancel()
            tipRotationTask = nil
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
                    cameraError = "Could not load the selected photo. Please try a different image."
                    showCameraError = true
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
        .alert("Capture Error", isPresented: $showCameraError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cameraError ?? "An unexpected error occurred.")
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

    // MARK: - Tip Rotation

    private func startTipRotation() {
        tipRotationTask?.cancel()
        tipRotationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled, !fusionState.isActive else { continue }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentTipIndex = (currentTipIndex + 1) % cameraTips.count
                    }
                }
            }
        }
    }

    // MARK: - Single-Shot Capture

    private func capturePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        logger.info("Shutter tapped — capturing photo")
        HapticManager.medium()

        Task {
            defer { isCapturing = false }
            do {
                let image = try await cameraManager.capturePhoto()
                logger.info("Photo captured successfully: \(image.size.width)x\(image.size.height)")
                cameraManager.stopSession()
                onPhotoCaptured(image)
            } catch {
                logger.error("Photo capture failed: \(error.localizedDescription)")
                cameraError = error.localizedDescription
                showCameraError = true
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
            guard RemoteConfigManager.shared.fusionModeEnabled else {
                logger.info("Fusion mode disabled via remote config")
                return
            }
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
        guard fusionState.canCapture, !isCapturing else {
            logger.info("Fusion mode — max 3 shots reached or capture in progress")
            return
        }
        isCapturing = true

        logger.info("Fusion shutter tapped — capturing shot \(fusionState.shotCount + 1)/3")
        HapticManager.medium()

        Task {
            defer { isCapturing = false }
            do {
                let image = try await cameraManager.capturePhoto()
                logger.info("Fusion shot captured: \(image.size.width)x\(image.size.height)")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    fusionState.addImage(image)
                }
                // Camera stays running — do NOT stop session
            } catch {
                logger.error("Fusion photo capture failed: \(error.localizedDescription)")
                cameraError = error.localizedDescription
                showCameraError = true
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
