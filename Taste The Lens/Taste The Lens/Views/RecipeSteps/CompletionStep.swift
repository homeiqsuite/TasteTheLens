import SwiftUI

private enum CompletionSheet: Identifiable {
    case authPrompt
    case paywall
    case createChallenge
    case budgetInput
    case culturePicker

    var id: String {
        switch self {
        case .authPrompt: return "authPrompt"
        case .paywall: return "paywall"
        case .createChallenge: return "createChallenge"
        case .budgetInput: return "budgetInput"
        case .culturePicker: return "culturePicker"
        }
    }
}

struct CompletionStep: View {
    let recipe: Recipe
    let servingCount: Int
    var bottomInset: CGFloat = 100
    @State private var exportImage: UIImage?
    @State private var storiesExportImage: UIImage?
    @State private var isCreatingChallenge = false
    @State private var challengeError: String?
    @State private var budgetAmount: Double = 15
    @State private var showReimaginTooltip = false
    @State private var isGeneratingShoppingList = false
    @State private var isRenderingShareImage = false
    @State private var isSharingRecipeLink = false
    @State private var activeSheet: CompletionSheet?
    @AppStorage("hasSeenReimaginTooltip") private var hasSeenReimaginTooltip = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer().frame(height: 20)

                // Completion header
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.gold)

                Text("Ready to Plate!")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)

                Text("You've completed all the steps. Share your creation or try something new.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 12)

                // Primary share actions
                VStack(spacing: 10) {
                    // Share Image
                    Menu {
                        Button {
                            renderAndShare(format: .square)
                        } label: {
                            Label("Share Square (1:1)", systemImage: "square")
                        }
                        Button {
                            renderAndShare(format: .stories)
                        } label: {
                            Label("Share to Stories (9:16)", systemImage: "rectangle.portrait")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRenderingShareImage {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Theme.darkTextPrimary)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 14))
                            }
                            Text(isRenderingShareImage ? "Rendering..." : "Share Image")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Theme.darkTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 16))
                    }

                    // Share Recipe (deep link)
                    Button {
                        shareRecipeLink()
                    } label: {
                        HStack(spacing: 8) {
                            if isSharingRecipeLink {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Theme.textPrimary)
                            } else {
                                Image(systemName: "link")
                                    .font(.system(size: 14))
                            }
                            Text(isSharingRecipeLink ? "Preparing..." : "Share Recipe")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.buttonBg, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isSharingRecipeLink)
                }
                .padding(.horizontal, 20)

                // Reimagine tooltip
                if showReimaginTooltip {
                    CoachTooltip(
                        text: "Generate a fresh take on this dish",
                        icon: "arrow.trianglehead.2.clockwise",
                        pointer: .down
                    ) {
                        showReimaginTooltip = false
                        hasSeenReimaginTooltip = true
                    }
                    .transition(.opacity)
                    .padding(.horizontal, 20)
                }

                // Secondary action grid
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    // Shopping List
                    Button {
                        HapticManager.medium()
                        isGeneratingShoppingList = true
                        DispatchQueue.main.async {
                            shareShoppingList()
                            isGeneratingShoppingList = false
                        }
                    } label: {
                        completionTile(
                            icon: isGeneratingShoppingList ? "hourglass" : "list.clipboard",
                            label: "Shopping List",
                            accent: Theme.primary
                        )
                    }

                    // Simplify
                    Button {
                        simplifyRecipe()
                    } label: {
                        completionTile(icon: "leaf", label: "Simplify", accent: Theme.visual)
                    }

                    // Reimagine
                    Menu {
                        Button {
                            reimagineRecipe()
                        } label: {
                            Label("Something New", systemImage: "sparkles")
                        }
                        Divider()
                        ForEach(ReimagineCourseType.allCases) { course in
                            Button {
                                reimagineRecipe(as: course.rawValue)
                            } label: {
                                Label(course.label, systemImage: course.icon)
                            }
                        }
                        Divider()
                        Button {
                            activeSheet = .budgetInput
                        } label: {
                            Label("On a Budget", systemImage: "dollarsign.circle")
                        }
                        Divider()
                        Button {
                            activeSheet = .culturePicker
                        } label: {
                            Label("Culture", systemImage: "globe")
                        }
                    } label: {
                        completionTile(
                            icon: "arrow.trianglehead.2.clockwise",
                            label: "Reimagine",
                            accent: Theme.gold
                        )
                    }

                    // Throw the Gauntlet
                    Button {
                        throwTheGauntlet()
                    } label: {
                        completionTile(
                            icon: EntitlementManager.shared.requiresUpgrade(for: .fullChallenges) ? "lock.fill" : "flag.checkered",
                            label: "Throw the Gauntlet",
                            accent: Theme.gold
                        )
                    }
                }
                .padding(.horizontal, 20)

                Color.clear.frame(height: bottomInset)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .onAppear {
            if !hasSeenReimaginTooltip {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { showReimaginTooltip = true }
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .authPrompt:
                AuthPromptSheet()
            case .paywall:
                PaywallView(context: .featureGated(.fullChallenges))
            case .createChallenge:
                challengeConfirmationSheet
            case .budgetInput:
                budgetInputSheet
            case .culturePicker:
                CulturePickerView { selected in
                    activeSheet = nil
                    reimagineRecipe(cultureName: selected)
                }
            }
        }
    }

    // MARK: - Completion Tile

    private func completionTile(icon: String, label: String, accent: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }

    // MARK: - Actions

    private func simplifyRecipe() {
        guard EntitlementManager.shared.hasAccess(to: .reimagination) else {
            NotificationCenter.default.post(name: .simplifyRecipe, object: nil, userInfo: [
                "showPaywall": true,
                "paywallContext": "reimagination"
            ])
            return
        }
        guard UsageTracker.shared.canGenerate else {
            NotificationCenter.default.post(name: .simplifyRecipe, object: nil, userInfo: ["showPaywall": true])
            return
        }
        NotificationCenter.default.post(
            name: .simplifyRecipe,
            object: nil,
            userInfo: [
                "excludeDishName": recipe.dishName,
                "inspirationImageData": recipe.inspirationImageData
            ]
        )
    }

    private func shareRecipeLink() {
        if let url = DeepLinkHandler.url(for: recipe) {
            HapticManager.medium()
            presentShareSheet(items: [recipe.dishName, url])
            return
        }

        // Recipe not yet synced — need remoteId to create a shareable link
        guard AuthManager.shared.isAuthenticated else {
            activeSheet = .authPrompt
            return
        }

        isSharingRecipeLink = true
        Task {
            await SyncManager.shared.syncRecipe(recipe)
            await MainActor.run {
                isSharingRecipeLink = false
                if let url = DeepLinkHandler.url(for: recipe) {
                    HapticManager.medium()
                    presentShareSheet(items: [recipe.dishName, url])
                }
            }
        }
    }

    private func shareShoppingList() {
        let text = ShoppingListGenerator.generate(from: recipe, servingCount: servingCount)
        presentShareSheet(items: [text])
    }

    private func reimagineRecipe(as courseType: String? = nil, budgetLimit: Double? = nil, cultureName: String? = nil) {
        guard EntitlementManager.shared.hasAccess(to: .reimagination) else {
            NotificationCenter.default.post(name: .reimagineRecipe, object: nil, userInfo: [
                "showPaywall": true,
                "paywallContext": "reimagination"
            ])
            return
        }
        guard UsageTracker.shared.canGenerate else {
            NotificationCenter.default.post(name: .reimagineRecipe, object: nil, userInfo: ["showPaywall": true])
            return
        }
        var userInfo: [String: Any] = [
            "excludeDishName": recipe.dishName,
            "inspirationImageData": recipe.inspirationImageData
        ]
        if let courseType {
            userInfo["courseType"] = courseType
        }
        if let budgetLimit {
            userInfo["budgetLimit"] = budgetLimit
        }
        if let cultureName {
            userInfo["cultureName"] = cultureName
        }
        NotificationCenter.default.post(
            name: .reimagineRecipe,
            object: nil,
            userInfo: userInfo
        )
    }

    private func throwTheGauntlet() {
        guard !EntitlementManager.shared.requiresUpgrade(for: .fullChallenges) else {
            activeSheet = .paywall
            return
        }
        guard AuthManager.shared.isAuthenticated else {
            activeSheet = .authPrompt
            return
        }
        activeSheet = .createChallenge
    }

    private enum ShareFormat { case square, stories }

    private func renderAndShare(format: ShareFormat) {
        isRenderingShareImage = true
        // Check cache first
        switch format {
        case .square:
            if let exportImage {
                isRenderingShareImage = false
                presentShareSheet(items: [exportImage])
                return
            }
        case .stories:
            if let storiesExportImage {
                isRenderingShareImage = false
                presentShareSheet(items: [storiesExportImage])
                return
            }
        }
        // Render on next run loop to let spinner appear
        DispatchQueue.main.async {
            let image: UIImage?
            switch format {
            case .square:
                let renderer = ImageRenderer(content:
                    SideBySideExportView(recipe: recipe)
                        .frame(width: 1080, height: 1080)
                )
                renderer.scale = 2.0
                image = renderer.uiImage
                exportImage = image
            case .stories:
                let renderer = ImageRenderer(content:
                    StoriesExportView(recipe: recipe)
                        .frame(width: 1080, height: 1920)
                )
                renderer.scale = 2.0
                image = renderer.uiImage
                storiesExportImage = image
            }
            isRenderingShareImage = false
            if let image {
                presentShareSheet(items: [image])
            }
        }
    }


    private func presentShareSheet(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        activityVC.popoverPresentationController?.sourceView = presenter.view
        presenter.present(activityVC, animated: true)
    }

    // MARK: - Sheets

    private var challengeConfirmationSheet: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.gold)

                    Text("Throw the Gauntlet")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text("Challenge the community to cook **\(recipe.dishName)** and photograph their real-world attempt.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let challengeError {
                        Text(challengeError)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        Task {
                            isCreatingChallenge = true
                            challengeError = nil
                            do {
                                _ = try await ChallengeService.shared.createChallenge(recipe: recipe)
                                HapticManager.success()
                                activeSheet = nil
                            } catch {
                                challengeError = error.localizedDescription
                                HapticManager.error()
                            }
                            isCreatingChallenge = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isCreatingChallenge {
                                ProgressView().tint(Theme.darkBg)
                            }
                            Text(isCreatingChallenge ? "Publishing..." : "Publish Challenge")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Theme.darkBg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isCreatingChallenge)
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { activeSheet = nil }
                        .foregroundStyle(Theme.gold)
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var budgetInputSheet: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.gold)

                    Text("Budget Reimagine")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text("Generate a new version of this dish that costs less than your budget.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        Text(String(format: "$%.0f", budgetAmount))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.gold)

                        Slider(value: $budgetAmount, in: 5...50, step: 5)
                            .tint(Theme.gold)
                            .padding(.horizontal, 32)

                        HStack {
                            Text("$5")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.darkTextSecondary)
                            Spacer()
                            Text("$50")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.darkTextSecondary)
                        }
                        .padding(.horizontal, 36)
                    }

                    Button {
                        activeSheet = nil
                        reimagineRecipe(budgetLimit: budgetAmount)
                    } label: {
                        Text("Reimagine Under \(String(format: "$%.0f", budgetAmount))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.darkBg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { activeSheet = nil }
                        .foregroundStyle(Theme.gold)
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Culture Picker

private struct CultureEntry: Identifiable {
    let id = UUID()
    let flag: String
    let name: String
}

private let cultures: [CultureEntry] = [
    .init(flag: "🇫🇷", name: "French"),
    .init(flag: "🇯🇵", name: "Japanese"),
    .init(flag: "🇲🇽", name: "Mexican"),
    .init(flag: "🇮🇳", name: "Indian"),
    .init(flag: "🇨🇳", name: "Chinese"),
    .init(flag: "🇰🇷", name: "Korean"),
    .init(flag: "🇹🇭", name: "Thai"),
    .init(flag: "🇻🇳", name: "Vietnamese"),
    .init(flag: "🇲🇦", name: "Moroccan"),
    .init(flag: "🇹🇷", name: "Turkish"),
    .init(flag: "🇵🇪", name: "Peruvian"),
    .init(flag: "🇧🇷", name: "Brazilian"),
    .init(flag: "🇯🇲", name: "Jamaican"),
    .init(flag: "🇬🇷", name: "Greek"),
    .init(flag: "🇪🇹", name: "Ethiopian"),
    .init(flag: "🇳🇬", name: "Nigerian"),
    .init(flag: "🇦🇷", name: "Argentine"),
    .init(flag: "🇵🇭", name: "Filipino"),
    .init(flag: "🇱🇧", name: "Lebanese"),
    .init(flag: "🇮🇷", name: "Persian"),
    .init(flag: "🇪🇸", name: "Spanish"),
    .init(flag: "🇩🇪", name: "German"),
    .init(flag: "🇵🇱", name: "Polish"),
    .init(flag: "🇸🇪", name: "Swedish"),
    .init(flag: "🇺🇸", name: "American"),
    .init(flag: "🇮🇹", name: "Italian"),
]

struct CulturePickerView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(cultures) { culture in
                            Button {
                                onSelect(culture.name)
                            } label: {
                                VStack(spacing: 6) {
                                    Text(culture.flag)
                                        .font(.system(size: 36))
                                    Text(culture.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.darkTextSecondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.darkSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(PressedScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Choose a Culture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
