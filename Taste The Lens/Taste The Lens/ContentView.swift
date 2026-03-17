import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "ContentView")

enum AppScreen: Equatable {
    case camera
    case processing
    case recipeCard
}

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showSplash = false
    @State private var vm = MainViewModel()
    @Namespace private var heroNamespace

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            switch vm.currentScreen {
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
                        vm.currentScreen = .camera
                    }
                }

            case .recipeCard:
                if let recipe = vm.pipeline.completedRecipe {
                    recipeCardScreen(recipe: recipe)
                        .transition(.opacity)
                } else {
                    Color.clear.onAppear {
                        logger.error("Recipe card screen shown but completedRecipe is nil")
                        vm.currentScreen = .camera
                    }
                }
            }

            // Error toast
            if vm.showError, let message = vm.errorMessage {
                errorToast(message: message)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.85), value: vm.currentScreen)
        .fullScreenCover(isPresented: $showSplash) {
            SplashView(isPresented: $showSplash)
        }
        .sheet(isPresented: $vm.showSavedRecipes) {
            SavedRecipesView()
        }
        .sheet(isPresented: $vm.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
        }
        .onAppear {
            logger.info("ContentView appeared — hasSeenOnboarding: \(hasSeenOnboarding)")
            if !hasSeenOnboarding {
                showSplash = true
                hasSeenOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reimagineRecipe)) { notification in
            vm.handleReimaginNotification(notification)
        }
    }

    // MARK: - Screens

    private var cameraScreen: some View {
        ZStack {
            CameraView { image in
                vm.handlePhotoCaptured(image)
            }

            // Top bar: settings (left) + saved recipes (right)
            VStack {
                HStack {
                    Button {
                        vm.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8)

                    Spacer()

                    Button {
                        vm.showSavedRecipes = true
                    } label: {
                        Image(systemName: "book.closed")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
    }

    private func processingScreen(image: UIImage) -> some View {
        ProcessingView(capturedImage: image, pipeline: vm.pipeline, onCancel: {
            vm.cancelProcessing()
        })
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
                                vm.resetToCamera()
                            }
                        } label: {
                            Image(systemName: "camera")
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
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
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
