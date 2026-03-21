import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "ContentView")

enum AppScreen: Equatable {
    case dashboard
    case camera
    case processing
    case recipeCard
}

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("debug_processingStyle") private var processingStyleRaw = ProcessingStyle.classic.rawValue
    @State private var showSplash = false
    @State private var showChefOnboarding = false
    @State private var showDebugMenu = false
    @State private var vm = MainViewModel()
    @Namespace private var heroNamespace

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let bg = Theme.darkBg

    var body: some View {
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
                    recipeCardScreen(recipe: recipe)
                        .transition(.opacity)
                } else {
                    Color.clear.onAppear {
                        logger.error("Recipe card screen shown but completedRecipe is nil")
                        vm.currentScreen = .dashboard
                    }
                }
            }

            // Error toast
            if vm.showError, let message = vm.errorMessage {
                errorToast(message: message)
            }
        }
        .onTapGesture(count: 3) {
            showDebugMenu = true
        }
        .sheet(isPresented: $showDebugMenu) {
            DebugMenuView()
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.85), value: vm.currentScreen)
        .preferredColorScheme(vm.currentScreen == .dashboard ? .light : .dark)
        .fullScreenCover(isPresented: $showSplash) {
            SplashView(isPresented: $showSplash)
        }
        .fullScreenCover(isPresented: $showChefOnboarding) {
            ChefOnboardingView(isPresented: $showChefOnboarding)
        }
        .onChange(of: showSplash) { _, newValue in
            if !newValue && !hasSeenOnboarding {
                showChefOnboarding = true
                hasSeenOnboarding = true
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
            TastingMenuListView()
        }
        .onAppear {
            logger.info("ContentView appeared — hasSeenOnboarding: \(hasSeenOnboarding)")
            if !hasSeenOnboarding {
                showSplash = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reimagineRecipe)) { notification in
            vm.handleReimaginNotification(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .addMenuCourse)) { notification in
            vm.handleAddMenuCourse(notification)
        }
    }

    // MARK: - Screens

    @State private var showBudgetPicker = false
    @State private var showChefPicker = false

    private var cameraScreen: some View {
        ZStack {
            CameraView { image in
                vm.handlePhotoCaptured(image)
            } onChefTapped: {
                showChefPicker = true
            }

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
                    .padding(.top, 8)

                    Button {
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
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
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
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                ChefSelectionView()
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showChefPicker = false }
                        .foregroundStyle(Theme.gold)
                }
            }
            .presentationDetents([.medium])
        }
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
        let style = ProcessingStyle(rawValue: processingStyleRaw) ?? .classic
        Group {
            switch style {
            case .classic:
                ProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() })
            case .miseEnPlace:
                MiseEnPlaceProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() })
            case .colorToIngredient:
                ColorToIngredientProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() })
            case .kitchenPass:
                KitchenPassProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() })
            case .splitScreen:
                SplitScreenProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: { vm.cancelProcessing() })
            }
        }
        .task(id: vm.pipeline.id) {
            vm.startProcessing(modelContext: modelContext, reduceMotion: reduceMotion)
        }
    }

    private func recipeCardScreen(recipe: Recipe) -> some View {
        NavigationStack {
            RecipeCardView(recipe: recipe)
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

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.4), value: vm.showError)
    }
}
