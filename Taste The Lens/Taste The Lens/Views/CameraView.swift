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
    @State private var tooltipTask: Task<Void, Never>?
    private let cameraTips = [
        "Point at anything. Art, architecture, a sunset. Tap to taste.",
        "Good lighting helps AI see more detail",
        "Try interesting textures and colors",
    ]
    @AppStorage("selectedChef") private var selectedChef = "default"
    @AppStorage("hasSeenFusionTooltip") private var hasSeenFusionTooltip = false
    @AppStorage("hasSeenChefTooltip") private var hasSeenChefTooltip = false
    @State private var showChefTooltip = false
    @State private var chefButtonOffset: CGFloat = 0
    @State private var isViewVisible = false

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

                        // Chef picker — slides left when tooltip visible, fixed frame so HStack layout is stable
                        chefButton
                            .frame(width: 50, height: 50)
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
                            .padding(.bottom, 24)
                        }

                        Spacer()
                    }
                }
                .frame(height: 120)

                Spacer().frame(height: 40)
            }
            // Note: animation was intentionally removed from this VStack to prevent
            // it from leaking into ShutterButton. Fusion transitions are handled
            // by individual child views (FusionTrayView, hint text Group).
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
            isPulsing = true
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
            // Rotate camera tips every 6 seconds
            startTipRotation()
        }
        .onDisappear {
            isViewVisible = false
            tooltipTask?.cancel()
            tooltipTask = nil
            tipRotationTask?.cancel()
            tipRotationTask = nil
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

// MARK: - Preview

#Preview("Chef Tooltip") {
    // Static preview showing chef button slid left with tooltip above it
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            Text("Good lighting helps AI see more detail")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.darkTextSecondary)
                .padding(.horizontal, 40)

            Spacer().frame(height: 24)

            ZStack(alignment: .bottom) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())

                    Spacer()

                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                        )

                    Spacer()

                    // Chef button + tooltip, slid left, fixed 50pt frame for stable layout
                    Image(systemName: "frying.pan")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
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
                .padding(.horizontal, 32)
            }
            .frame(height: 120)

            Spacer().frame(height: 40)
        }
    }
}

#Preview("Fusion Tooltip") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            Text("Point at anything. Art, architecture, a sunset. Tap to taste.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.darkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 24)

            ZStack(alignment: .bottom) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())

                    Spacer()

                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 58, height: 58)
                        )

                    Spacer()

                    Image(systemName: "frying.pan")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .frame(width: 50, height: 50)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 32)

                // Fusion tooltip centered above shutter
                VStack(spacing: 0) {
                    FusionTooltip {}
                        .padding(.bottom, 24)
                    Spacer()
                }
            }
            .frame(height: 120)

            Spacer().frame(height: 40)
        }
    }
}
