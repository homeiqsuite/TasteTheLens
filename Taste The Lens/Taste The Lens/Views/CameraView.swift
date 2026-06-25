import SwiftUI
import PhotosUI
import os

private let logger = makeLogger(category: "CameraView")

struct CameraView: View {
    @State var cameraManager = CameraManager()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var fusionState = FusionModeState()
    @State private var showFusionTooltip = false
    @State private var cameraError: String?
    @State private var showCameraError = false
    @State private var isCapturing = false
    @State private var tooltipTask: Task<Void, Never>?
    @AppStorage("selectedChef") private var selectedChef = "default"
    @AppStorage("hasSeenFusionTooltip") private var hasSeenFusionTooltip = false
    @AppStorage("hasSeenChefTooltip") private var hasSeenChefTooltip = false
    @State private var showChefTooltip = false
    @State private var chefButtonOffset: CGFloat = 0
    @State private var isViewVisible = false

    var onPhotoCaptured: (UIImage) -> Void
    var onFusionPhotoCaptured: (([UIImage]) -> Void)?
    var onChefTapped: () -> Void

    /// Show the mode pill until the first fusion shot lands — after that the
    /// fusion tray itself is the mode indicator. Hidden when fusion is disabled.
    private var shouldShowModePill: Bool {
        RemoteConfigManager.shared.fusionModeEnabled && fusionState.capturedImages.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()

                ViewfinderCornersView()
                    .frame(width: 280, height: 280)
                    .opacity(isCapturing ? 0.4 : 1)
                    .animation(.easeInOut(duration: 0.3), value: isCapturing)
                    .allowsHitTesting(false)
            } else {
                permissionDeniedView
            }

            // UI overlay
            VStack(spacing: 0) {
                Spacer()

                // Fusion tray (above hint when active)
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

                // Fusion hint
                if fusionState.isActive {
                    Text("Fusion Mode — capture 2-3 shots")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.gold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }

                // Single / Fusion mode toggle
                if shouldShowModePill {
                    ModeTogglePill(isFusion: fusionState.isActive) { _ in
                        toggleFusionMode()
                    }
                    .transition(.opacity)
                }

                Spacer().frame(height: 20)

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

                        // Chef picker — slides left when tooltip visible, fixed frame so HStack layout is stable
                        chefButton
                            .frame(width: 50, height: 50)
                    }
                    .padding(.horizontal, 40)

                    // Fusion tooltip (overlaid above shutter, doesn't affect layout)
                    VStack(spacing: 0) {
                        if showFusionTooltip {
                            FusionTooltip {
                                showFusionTooltip = false
                                hasSeenFusionTooltip = true
                            }
                            .transition(.opacity)
                            .padding(.bottom, 24)
                        }

                        Spacer()
                    }
                }
                .frame(height: 120)

                Spacer().frame(height: 32)
            }
            // No .animation() on this VStack — it would leak into ShutterButton.
            // Child views (tray, hint, pill) animate via their own transitions.
        }
        .task {
            logger.info("Checking camera permission...")
            await cameraManager.checkPermission()
            logger.info("Permission granted: \(cameraManager.permissionGranted)")
            if cameraManager.permissionGranted {
                cameraManager.startSession()
            }
        }
        .onAppear {
            isViewVisible = true
            cameraManager.startSession()
            // Stagger tooltips: show fusion first, then chef after fusion dismisses
            tooltipTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled, isViewVisible else { return }
                if !hasSeenFusionTooltip {
                    withAnimation { showFusionTooltip = true }
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled, isViewVisible else { return }
                }
                if !hasSeenChefTooltip {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled, isViewVisible else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        chefButtonOffset = -80
                    }
                    try? await Task.sleep(for: .seconds(0.3))
                    guard !Task.isCancelled, isViewVisible else { return }
                    withAnimation { showChefTooltip = true }
                }
            }
        }
        .onDisappear {
            isViewVisible = false
            tooltipTask?.cancel()
            tooltipTask = nil
            cameraManager.stopSession()
            if fusionState.isActive {
                fusionState.reset()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if cameraManager.permissionGranted {
                cameraManager.startSession()
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

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.gold)
                    .clipShape(Capsule())
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await cameraManager.checkPermission() }
        }
    }

    // MARK: - Chef Button + Tooltip

    /// Chef button that slides left to make room for the tooltip, then slides back
    private var chefButton: some View {
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
        .overlay(alignment: .bottom) {
            if showChefTooltip {
                CoachTooltip(
                    text: "Pick your chef",
                    icon: "person.crop.circle",
                    pointer: .down
                ) {
                    dismissChefTooltip()
                }
                .fixedSize()
                .transition(.opacity)
                .offset(y: -58)
            }
        }
        .offset(x: chefButtonOffset)
    }

    private func dismissChefTooltip() {
        showChefTooltip = false
        hasSeenChefTooltip = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            chefButtonOffset = 0
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

// MARK: - Preview Helpers

private func previewCircleButton(_ icon: String) -> some View {
    Image(systemName: icon)
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(Theme.darkTextSecondary)
        .frame(width: 50, height: 50)
        .background(Color.black.opacity(0.3))
        .clipShape(Circle())
}

// MARK: - Preview

#Preview("Chef Tooltip") {
    // Static preview: Single mode with chef button slid left and tooltip above it
    ZStack {
        Color.black.ignoresSafeArea()

        ViewfinderCornersView()
            .frame(width: 280, height: 280)

        VStack(spacing: 0) {
            Spacer()

            ModeTogglePill(isFusion: false) { _ in }

            Spacer().frame(height: 20)

            ZStack(alignment: .bottom) {
                HStack {
                    previewCircleButton("photo.on.rectangle")

                    Spacer()

                    ShutterButton(action: {})

                    Spacer()

                    previewCircleButton("frying.pan")
                        .overlay(alignment: .bottom) {
                            CoachTooltip(
                                text: "Pick your chef",
                                icon: "person.crop.circle",
                                pointer: .down
                            ) {}
                            .fixedSize()
                            .offset(y: -58)
                        }
                        .offset(x: -80)
                        .frame(width: 50, height: 50)
                }
                .padding(.horizontal, 40)
            }
            .frame(height: 120)

            Spacer().frame(height: 32)
        }
    }
}

#Preview("Fusion Tooltip") {
    // Static preview: Single mode with the fusion tooltip above the shutter
    ZStack {
        Color.black.ignoresSafeArea()

        ViewfinderCornersView()
            .frame(width: 280, height: 280)

        VStack(spacing: 0) {
            Spacer()

            ModeTogglePill(isFusion: false) { _ in }

            Spacer().frame(height: 20)

            ZStack(alignment: .bottom) {
                HStack {
                    previewCircleButton("photo.on.rectangle")

                    Spacer()

                    ShutterButton(action: {})

                    Spacer()

                    previewCircleButton("frying.pan")
                }
                .padding(.horizontal, 40)

                // Fusion tooltip centered above shutter
                VStack(spacing: 0) {
                    FusionTooltip {}
                        .padding(.bottom, 24)
                    Spacer()
                }
            }
            .frame(height: 120)

            Spacer().frame(height: 32)
        }
    }
}
