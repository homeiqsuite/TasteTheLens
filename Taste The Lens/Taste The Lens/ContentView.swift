import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "ContentView")

enum AppScreen {
    case camera
    case processing
    case recipeCard
}

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showSplash = false
    @State private var currentScreen: AppScreen = .camera
    @State private var capturedImage: UIImage?
    @State private var pipeline = ImageAnalysisPipeline()
    @State private var showSavedRecipes = false
    @State private var errorMessage: String?
    @State private var showError = false

    @Environment(\.modelContext) private var modelContext

    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)
    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            switch currentScreen {
            case .camera:
                cameraScreen

            case .processing:
                if let image = capturedImage {
                    processingScreen(image: image)
                } else {
                    // Safety fallback — should not happen
                    Color.clear.onAppear {
                        logger.error("Processing screen shown but capturedImage is nil")
                        currentScreen = .camera
                    }
                }

            case .recipeCard:
                if let recipe = pipeline.completedRecipe {
                    recipeCardScreen(recipe: recipe)
                } else {
                    Color.clear.onAppear {
                        logger.error("Recipe card screen shown but completedRecipe is nil")
                        currentScreen = .camera
                    }
                }
            }

            // Error toast
            if showError, let message = errorMessage {
                errorToast(message: message)
            }
        }
        .fullScreenCover(isPresented: $showSplash) {
            SplashView(isPresented: $showSplash)
        }
        .sheet(isPresented: $showSavedRecipes) {
            SavedRecipesView()
        }
        .onAppear {
            logger.info("ContentView appeared — hasSeenOnboarding: \(hasSeenOnboarding)")
            if !hasSeenOnboarding {
                showSplash = true
                hasSeenOnboarding = true
            }
        }
    }

    // MARK: - Screens

    private var cameraScreen: some View {
        ZStack {
            CameraView { image in
                logger.info("Photo received from CameraView — transitioning to processing")
                capturedImage = image
                pipeline = ImageAnalysisPipeline()
                currentScreen = .processing
            }

            // Saved recipes button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSavedRecipes = true
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
        ProcessingView(capturedImage: image, pipeline: pipeline)
            .task {
                logger.info("Processing .task fired — starting pipeline")
                await pipeline.process(image: image, modelContext: modelContext)

                logger.info("Pipeline finished — state: \(String(describing: pipeline.state))")

                if pipeline.state == .complete {
                    logger.info("Transitioning to recipe card")
                    withAnimation(.easeInOut(duration: 0.6)) {
                        currentScreen = .recipeCard
                    }
                } else if case .rejected(let reason) = pipeline.state {
                    logger.info("Image rejected — \(reason)")
                    errorMessage = reason
                    showError = true
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { showError = false }
                        currentScreen = .camera
                    }
                } else if case .failed(let message) = pipeline.state {
                    logger.error("Pipeline failed — showing error: \(message)")
                    errorMessage = message
                    showError = true
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { showError = false }
                        currentScreen = .camera
                    }
                }
            }
    }

    private func recipeCardScreen(recipe: Recipe) -> some View {
        NavigationStack {
            RecipeCardView(recipe: recipe)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation {
                                currentScreen = .camera
                                capturedImage = nil
                                pipeline = ImageAnalysisPipeline()
                            }
                        } label: {
                            Image(systemName: "camera")
                                .foregroundStyle(gold)
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
                    .foregroundStyle(gold)
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
        .animation(.spring(response: 0.4), value: showError)
    }
}
