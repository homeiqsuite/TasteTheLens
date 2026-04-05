import SwiftUI
import SwiftData
import os

private let logger = makeLogger(category: "ContentView")

enum AppScreen: Equatable {
    case dashboard
    case camera
    case processing
    case recipeCard
}

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("debug_processingStyle") private var processingStyleRaw = ProcessingStyle.kitchenPass.rawValue
    @AppStorage("selectedChef") private var selectedChef = "default"
    @State private var showOnboarding = false
    @State private var showDisplayNamePrompt = false
    #if !PRODUCTION
    @State private var showDebugMenu = false
    #endif
    @State private var vm = MainViewModel()
    @Namespace private var heroNamespace

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let bg = Theme.darkBg

    private var dashboardColorScheme: ColorScheme {
        guard vm.currentScreen == .dashboard else { return .dark }
        let chef = ChefPersonality(rawValue: selectedChef) ?? .defaultChef
        return chef.theme.prefersDarkMode ? .dark : .light
    }

    var body: some View {
        if RemoteConfigManager.shared.maintenanceMode {
            MaintenanceView(message: RemoteConfigManager.shared.maintenanceMessage)
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        ZStack {
            bg.ignoresSafeArea()

            switch vm.currentScreen {
            case .dashboard:
                DashboardView(vm: vm)
                    .transition(.opacity)

            case .camera:
                cameraScreen
                    .transition(.opacity)

            case .processing:
                if let image = vm.capturedImage {
                    processingScreen(image: image)
                        .transition(.opacity)
                } else {
                    Color.clear.onAppear {
                        logger.error("Processing screen shown but capturedImage is nil")
                        vm.currentScreen = .dashboard
                    }
                }

            case .recipeCard:
                if let recipe = vm.pipeline.completedRecipe {
                    recipeCardScreen(recipe: recipe, isOnboardingFlow: vm.isOnboardingFlow)
                        .transition(.opacity)
                } else {
                    Color.clear.onAppear {
                        logger.error("Recipe card screen shown but completedRecipe is nil")
                        vm.currentScreen = .dashboard
                    }
                }
            }

            // Offline banner
            if !NetworkMonitor.shared.isConnected || NetworkMonitor.shared.wasDisconnected || OfflineCaptureQueue.shared.queueCount > 0 {
                OfflineBannerView(
                    isConnected: NetworkMonitor.shared.isConnected,
                    wasDisconnected: NetworkMonitor.shared.wasDisconnected,
                    queueCount: OfflineCaptureQueue.shared.queueCount,
                    isProcessingQueue: OfflineCaptureQueue.shared.isProcessingQueue,
                    processingIndex: OfflineCaptureQueue.shared.processingIndex,
                    onProcess: {
                        Task {
                            let countBefore = OfflineCaptureQueue.shared.queueCount
                            await OfflineCaptureQueue.shared.processQueue(modelContext: modelContext)
                            if countBefore > 0 && OfflineCaptureQueue.shared.queueCount == 0 {
                                vm.showTemporaryNotice("All queued photos processed")
                            }
                        }
                    }
                )
            }

            // Notice toast (non-navigating, for queue confirmations)
            if vm.showNotice, let message = vm.noticeMessage {
                noticeToast(message: message)
            }

            // Error toast
            if vm.showError, let message = vm.errorMessage {
                errorToast(message: message)
            }
        }
        #if !PRODUCTION
        .onTapGesture(count: 3) {
            showDebugMenu = true
        }
        .sheet(isPresented: $showDebugMenu) {
            DebugMenuView()
        }
        #endif
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.85), value: vm.currentScreen)
        .preferredColorScheme(dashboardColorScheme)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onChange(of: showOnboarding) { _, newValue in
            if !newValue {
                hasSeenOnboarding = true
                if AuthManager.shared.isAuthenticated {
                    // User signed in during onboarding — stay on dashboard
                    return
                }
                // Normal onboarding completion — take user to camera
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    vm.currentScreen = .camera
                }
                // Mark that next recipe is from onboarding flow (with delay to avoid timing issues)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    vm.isOnboardingFlow = true
                }
            }
        }
        .sheet(isPresented: $vm.showSavedRecipes) {
            SavedRecipesView()
        }
        .sheet(isPresented: $vm.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView(context: vm.paywallContext)
        }
        .sheet(isPresented: $vm.showChallengeFeed) {
            ChallengeFeedView()
        }
        .sheet(isPresented: $vm.showTastingMenus) {
            TastingMenuListView(initialInviteCode: vm.deepLinkedInviteCode)
                .onDisappear { vm.deepLinkedInviteCode = nil }
        }
        .sheet(isPresented: $vm.showPrivacyNotice) {
            PrivacyNoticeSheet {
                vm.acceptPrivacyNotice()
            }
        }
        .onAppear {
            logger.info("ContentView appeared — hasSeenOnboarding: \(hasSeenOnboarding)")
            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: AuthManager.shared.isAuthenticated) { wasAuthenticated, isNowAuthenticated in
            if !wasAuthenticated && isNowAuthenticated {
                Task {
                    await StoreManager.shared.checkLegacySubscription()
                    await UsageTracker.shared.reconcileCreditsIfNeeded()
                    await UsageTracker.shared.claimWelcomeCreditsIfNeeded()
                    await UsageTracker.shared.syncUsageFromServer()
                    await UsageTracker.shared.syncCreditsFromServer()
                    await SyncManager.shared.claimLocalRecipes(modelContext: modelContext)
                    await SyncManager.shared.syncAll(modelContext: modelContext)
                    await PushNotificationService.shared.requestPermission()
                    await PushNotificationService.shared.loadPreferences()
                    await SyncManager.shared.pullDietaryPreferences()

                    if AuthManager.shared.needsDisplayName && !showDisplayNamePrompt {
                        showDisplayNamePrompt = true
                    }
                }
            } else if wasAuthenticated && !isNowAuthenticated {
                // Sign-out: reset all user-specific state synchronously.
                UsageTracker.shared.resetForSignOut()
                // Reset per-user @AppStorage flags so the next user gets a fresh experience
                UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
                hasSeenOnboarding = false
                UserDefaults.standard.removeObject(forKey: "hasSeenAuthPrompt")
                UserDefaults.standard.removeObject(forKey: "hasSeenOfflineQueueDisclaimer")
            }
        }
        .sheet(isPresented: $showDisplayNamePrompt) {
            DisplayNamePromptView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .displayNameDismissedWithoutSaving)) { _ in
            vm.showTemporaryNotice("Set your display name in Settings > Profile")
        }
        .onReceive(NotificationCenter.default.publisher(for: SignInView.dismissedWithEmailForm)) { _ in
            vm.showTemporaryNotice("You can sign in anytime from Settings")
        }
        .onReceive(NotificationCenter.default.publisher(for: .reimagineRecipe)) { notification in
            vm.handleReimaginNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .simplifyRecipe)) { notification in
            vm.handleSimplifyNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addMenuCourse)) { notification in
            vm.handleAddMenuCourse(notification)
        }
        // #2: Clear stale pendingMenuCourse when app returns from background and we're not processing
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if vm.currentScreen != .processing {
                vm.pendingMenuCourse = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTastingMenuInvite)) { notification in
            if let code = notification.userInfo?["inviteCode"] as? String {
                vm.deepLinkedInviteCode = code
                vm.showTastingMenus = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .networkStatusChanged)) { _ in
            if NetworkMonitor.shared.isConnected {
                // Sync existing recipes on reconnect (queued photos require explicit user action)
                Task {
                    await SyncManager.shared.syncAll(modelContext: modelContext)
                }
            }
        }
    }

    // MARK: - Screens

    @State private var showBudgetPicker = false
    @State private var showChefPicker = false
    @State private var showBudgetTooltip = false
    @AppStorage("hasSeenBudgetTooltip") private var hasSeenBudgetTooltip = false
    @AppStorage("totalCaptureCount") private var totalCaptureCount = 0

    private var cameraScreen: some View {
        ZStack {
            CameraView(
                onPhotoCaptured: { image in
                    totalCaptureCount += 1
                    vm.handlePhotoCaptured(image)
                },
                onFusionPhotoCaptured: { images in
                    vm.handleFusionPhotoCaptured(images)
                },
                onChefTapped: {
                    showChefPicker = true
                }
            )

            // Top bar: back to dashboard (left), budget (right)
            VStack {
                HStack {
                    Button {
                        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.8)) {
                            vm.currentScreen = .dashboard
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.darkTextSecondary)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Back to dashboard")
                    .padding(.leading, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Credit balance pill
                    Button {
                        vm.paywallContext = .topUp
                        vm.showPaywall = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.grid.3x3.fill")
                                .font(.system(size: 12))
                            Text("\(UsageTracker.shared.remainingGenerations)")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(UsageTracker.shared.remainingGenerations <= 2 ? Theme.culinary : Theme.darkTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("\(UsageTracker.shared.remainingGenerations) credits remaining")
                    .accessibilityHint("Tap to view credit options")
                    .padding(.top, 8)

                    VStack(spacing: 4) {
                        Button {
                            if showBudgetTooltip {
                                showBudgetTooltip = false
                                hasSeenBudgetTooltip = true
                            }
                            showBudgetPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle")
                                    .font(.system(size: 14, weight: .medium))
                                if let budget = vm.budgetLimit {
                                    Text(String(format: "$%.0f", budget))
                                        .font(.system(size: 14, weight: .semibold))
                                } else {
                                    Text("Budget")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .foregroundStyle(vm.budgetLimit != nil ? Theme.gold : Theme.darkTextSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Capsule())
                        }

                        if showBudgetTooltip {
                            CoachTooltip(
                                text: "Set a budget to generate affordable meals",
                                icon: "dollarsign.circle",
                                pointer: .up
                            ) {
                                showBudgetTooltip = false
                                hasSeenBudgetTooltip = true
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .onAppear {
            if totalCaptureCount >= 3 && !hasSeenBudgetTooltip {
                Task {
                    try? await Task.sleep(for: .seconds(1.0))
                    withAnimation { showBudgetTooltip = true }
                }
            }
        }
        .sheet(isPresented: $showBudgetPicker) {
            cameraBudgetSheet
        }
        .sheet(isPresented: $showChefPicker) {
            cameraChefSheet
        }
    }

    private var cameraBudgetSheet: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Set a Budget")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.darkTextPrimary)
                        .padding(.top, 8)

                    Text("Generate meals that cost less than your target.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
                        budgetOption(nil, label: "Any")
                        budgetOption(10, label: "$10")
                        budgetOption(15, label: "$15")
                        budgetOption(20, label: "$20")
                        budgetOption(25, label: "$25")
                        budgetOption(30, label: "$30")
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showBudgetPicker = false }
                        .foregroundStyle(Theme.gold)
                }
            }
            .presentationDetents([.height(300)])
        }
    }

    private var cameraChefSheet: some View {
        ChefModeView(context: .forThisRecipe)
    }

    private func budgetOption(_ amount: Double?, label: String) -> some View {
        let isSelected = vm.budgetLimit == amount
        return Button {
            vm.budgetLimit = amount
            HapticManager.light()
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.darkBg : Theme.darkTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? Theme.gold : Theme.darkStroke)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func processingScreen(image: UIImage) -> some View {
        let style = ProcessingStyle(rawValue: processingStyleRaw) ?? .kitchenPass
        let fusionExtras = (vm.capturedImages?.dropFirst()).map(Array.init) ?? []
        Group {
            switch style {
            case .classic:
                ProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() }, additionalImages: fusionExtras)
            case .miseEnPlace:
                MiseEnPlaceProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() }, additionalImages: fusionExtras)
            case .colorToIngredient:
                ColorToIngredientProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() }, additionalImages: fusionExtras)
            case .kitchenPass:
                KitchenPassProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() }, additionalImages: fusionExtras)
            case .splitScreen:
                SplitScreenProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() }, additionalImages: fusionExtras)
            }
        }
        .task(id: vm.pipeline.id) {
            vm.startProcessing(modelContext: modelContext, reduceMotion: reduceMotion)
        }
    }

    private func recipeCardScreen(recipe: Recipe, isOnboardingFlow: Bool) -> some View {
        NavigationStack {
            RecipeCardView(recipe: recipe, isOnboardingFlow: isOnboardingFlow)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.8)) {
                                vm.resetToDashboard()
                            }
                        } label: {
                            Image(systemName: "house")
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
        }
    }

    // MARK: - Notice Toast

    private func noticeToast(message: String) -> some View {
        VStack {
            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.darkCardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.darkCardBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
            .onTapGesture {
                withAnimation { vm.showNotice = false }
            }
            .accessibilityLabel(message)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4), value: vm.showNotice)
    }

    // MARK: - Error Toast

    private func errorToast(message: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Theme.gold)
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.darkStroke)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.darkStroke, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .onTapGesture {
                withAnimation { vm.showError = false }
            }
            .accessibilityLabel("Error: \(message)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap to dismiss")

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.4), value: vm.showError)
    }
}

// MARK: - Privacy Notice Sheet

private struct PrivacyNoticeSheet: View {
    let onAccept: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.visual)
                            .padding(.top, 32)

                        Text("How Your Photos Are Used")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.darkTextPrimary)

                        Text("When you capture a photo, it's sent to AI services to analyze the scene and generate your recipe. Photos are processed in real-time and are not stored on external servers beyond processing.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.darkTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Text("Recipes are AI-generated for creative inspiration only. Always use your own judgment when preparing and tasting food. Try any recipe at your own risk.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.darkTextTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        // Expandable details
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showDetails.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("What do we use this for?")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Theme.visual)
                                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.visual)
                                }
                            }

                            if showDetails {
                                VStack(alignment: .leading, spacing: 10) {
                                    privacyBullet("Your photo is sent to AI to identify ingredients and scene context")
                                    privacyBullet("Photos are not stored permanently on any server")
                                    privacyBullet("No photo data is shared with third parties for advertising")
                                    privacyBullet("Accepting this notice is required to process your photo")
                                    privacyBullet("Recipes are AI-generated for inspiration only — try them at your own risk")
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                        Button {
                            if let url = URL(string: "https://tastethelens.com/privacy") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 13))
                                Text("Privacy Policy")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(Theme.darkTextTertiary)
                        }

                        Spacer().frame(height: 20)

                        Button {
                            onAccept()
                        } label: {
                            Text("I Understand")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.darkBg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .interactiveDismissDisabled()
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.visual.opacity(0.6))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.darkTextTertiary)
        }
    }
}
