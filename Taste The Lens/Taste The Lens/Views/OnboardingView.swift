import SwiftUI
import AVFoundation

enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case chef = 1
    case preferences = 2
    case camera = 3
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("selectedChef") private var selectedChef = "beginner"

    @State private var currentPage: OnboardingPage = .welcome

    // Page 1 — Welcome animation states
    @State private var fusionCalloutVisible = false
    @State private var heroVisible = false
    @State private var headlineVisible = false
    @State private var step1Visible = false
    @State private var step2Visible = false
    @State private var step3Visible = false
    @State private var connector1Visible = false
    @State private var connector2Visible = false
    @State private var welcomeCTAVisible = false
    @State private var shimmerPhase: CGFloat = -1.0
    @State private var ctaGlowRadius: CGFloat = 12
    // Step icon pulse states
    @State private var step1IconScale: CGFloat = 1.0
    @State private var step2IconScale: CGFloat = 1.0
    @State private var step3IconScale: CGFloat = 1.0

    // Page 2 — Chef animation states
    @State private var chefHeaderVisible = false
    @State private var chefCardVisible: [Bool] = [false, false, false, false]
    @State private var chefCTAVisible = false
    @State private var avatarFloat: CGFloat = 0

    // Page 3 — Camera animation states
    @State private var cameraIconVisible = false
    @State private var cameraTextVisible = false
    @State private var cameraText2Visible = false
    @State private var cameraCTAVisible = false
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring1Opacity: Double = 0.3
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring2Opacity: Double = 0.3

    // Page 3 — Preferences animation states
    @State private var prefsHeaderVisible = false
    @State private var prefsSkillVisible = false
    @State private var prefsDietaryVisible = false
    @State private var prefsCTAVisible = false
    @AppStorage("userSkillLevel") private var userSkillLevel = "homeCook"
    @State private var selectedDietaryPrefs: Set<DietaryPreference> = Set(DietaryPreference.current())

    @State private var showSignIn = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.darkBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                progressDots
                    .padding(.top, 16)

                // Page content
                ZStack {
                    switch currentPage {
                    case .welcome:
                        welcomePage
                            .transition(pageTransition)
                    case .chef:
                        chefPage
                            .transition(pageTransition)
                    case .preferences:
                        preferencesPage
                            .transition(pageTransition)
                    case .camera:
                        cameraPage
                            .transition(pageTransition)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .onChange(of: AuthManager.shared.isAuthenticated) { _, isAuth in
            if isAuth {
                // User signed in during onboarding — skip straight to dashboard
                isPresented = false
            }
        }
        .onAppear {
            triggerWelcomeAnimations()
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                Capsule()
                    .fill(page == currentPage ? Theme.gold : Theme.darkStroke)
                    .frame(width: page == currentPage ? 28 : 10, height: 10)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Page Transition

    private var pageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        HapticManager.medium()
        // Save dietary prefs when leaving preferences page
        if currentPage == .preferences {
            DietaryPreference.save(Array(selectedDietaryPrefs))
        }
        let next = OnboardingPage(rawValue: currentPage.rawValue + 1)
        if let next {
            resetAnimationStates()
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.85)) {
                currentPage = next
            }
        }
    }

    private func dismiss() {
        HapticManager.medium()
        withAnimation(.easeOut(duration: 0.4)) {
            isPresented = false
        }
    }

    // MARK: - Animation Orchestration

    private func resetAnimationStates() {
        heroVisible = false
        headlineVisible = false
        step1Visible = false
        step2Visible = false
        step3Visible = false
        connector1Visible = false
        connector2Visible = false
        welcomeCTAVisible = false
        fusionCalloutVisible = false
        step1IconScale = 1.0
        step2IconScale = 1.0
        step3IconScale = 1.0
        chefHeaderVisible = false
        chefCardVisible = [false, false, false, false]
        chefCTAVisible = false
        prefsHeaderVisible = false
        prefsSkillVisible = false
        prefsDietaryVisible = false
        prefsCTAVisible = false
        cameraIconVisible = false
        cameraTextVisible = false
        cameraText2Visible = false
        cameraCTAVisible = false
    }

    private func triggerWelcomeAnimations() {
        guard !reduceMotion else {
            heroVisible = true; headlineVisible = true
            step1Visible = true; step2Visible = true; step3Visible = true
            connector1Visible = true; connector2Visible = true
            fusionCalloutVisible = true; welcomeCTAVisible = true
            return
        }

        // Hero: immediate
        withAnimation(.easeOut(duration: 0.7)) { heroVisible = true }
        // Headline: 0.25s delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.6)) { headlineVisible = true }
        }
        // Step 1: 0.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.45)) { step1Visible = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { step1IconScale = 1.15 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step1IconScale = 1.0 }
            }
        }
        // Connector 1: 0.7s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) { connector1Visible = true }
        }
        // Step 2: 0.85s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.45)) { step2Visible = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { step2IconScale = 1.15 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step2IconScale = 1.0 }
            }
        }
        // Connector 2: 1.05s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.easeOut(duration: 0.3)) { connector2Visible = true }
        }
        // Step 3: 1.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.45)) { step3Visible = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { step3IconScale = 1.15 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { step3IconScale = 1.0 }
            }
        }
        // Fusion callout: 1.4s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.45)) { fusionCalloutVisible = true }
        }
        // CTA: 1.7s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.5)) { welcomeCTAVisible = true }
        }
        // Shimmer loop
        startShimmerLoop()
        // CTA glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                ctaGlowRadius = 18
            }
        }
    }

    private func startShimmerLoop() {
        guard !reduceMotion else { return }
        shimmerPhase = -1.0
        withAnimation(.easeInOut(duration: 2.5)) {
            shimmerPhase = 2.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            guard currentPage == .welcome else { return }
            startShimmerLoop()
        }
    }

    private func triggerChefAnimations() {
        guard !reduceMotion else {
            chefHeaderVisible = true
            chefCardVisible = [true, true, true, true]
            chefCTAVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.5)) { chefHeaderVisible = true }
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.12) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    chefCardVisible[i] = true
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.5)) { chefCTAVisible = true }
        }
        // Avatar float
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                avatarFloat = -2
            }
        }
    }

    private func triggerCameraAnimations() {
        guard !reduceMotion else {
            cameraIconVisible = true; cameraTextVisible = true
            cameraText2Visible = true; cameraCTAVisible = true
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { cameraIconVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) { cameraTextVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.5)) { cameraText2Visible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.5)) { cameraCTAVisible = true }
        }
        // Sonar rings
        startSonarRings()
    }

    private func startSonarRings() {
        guard !reduceMotion else { return }
        // Ring 1
        ring1Scale = 1.0; ring1Opacity = 0.3
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            ring1Scale = 1.8; ring1Opacity = 0.0
        }
        // Ring 2 offset by 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            ring2Scale = 1.0; ring2Opacity = 0.3
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                ring2Scale = 1.8; ring2Opacity = 0.0
            }
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero visual — transformation concept
            heroTransformation
                .padding(.bottom, 28)
                .scaleEffect(heroVisible ? 1.0 : 0.92)
                .opacity(heroVisible ? 1 : 0)

            // Headline with gold gradient + glow + shimmer
            VStack(spacing: 10) {
                Text("Turn Anything You See\nInto a Recipe")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.78, blue: 0.35),  // bright gold
                                Theme.gold,
                                Color(red: 0.85, green: 0.60, blue: 0.20)   // deeper gold
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Theme.gold.opacity(0.4), radius: 16, y: 2)
                    .overlay {
                        // Shimmer sweep
                        if !reduceMotion {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.15), location: 0.5),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0.5),
                                endPoint: UnitPoint(x: shimmerPhase, y: 0.5)
                            )
                            .blendMode(.overlay)
                            .allowsHitTesting(false)
                        }
                    }
                    .mask {
                        Text("Turn Anything You See\nInto a Recipe")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                Text("Snap a photo and let AI create\na gourmet dish from it")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(red: 0.69, green: 0.69, blue: 0.71)) // #B0B0B5
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 32)
            .opacity(headlineVisible ? 1 : 0)
            .offset(y: headlineVisible ? 0 : 16)

            // Step flow
            stepFlow
                .padding(.horizontal, 24)

            // Fusion mode callout
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Text("Long-press the shutter to combine photos with Fusion Mode")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.darkTextSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Theme.gold.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(Theme.gold.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .opacity(fusionCalloutVisible ? 1 : 0)
            .offset(y: fusionCalloutVisible ? 0 : 10)

            Spacer()

            // CTA + footer
            VStack(spacing: 16) {
                welcomeCTAButton { advance() }

                Button {
                    showSignIn = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(Theme.darkTextTertiary)
                        Text("Log in")
                            .foregroundStyle(Theme.gold)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 14))
                }
            }
            .padding(.bottom, 40)
            .opacity(welcomeCTAVisible ? 1 : 0)
            .offset(y: welcomeCTAVisible ? 0 : 12)
        }
    }

    // MARK: - Hero Image

    private var heroTransformation: some View {
        Color.clear
            .frame(height: 200)
            .overlay {
                Image("onboarding-hero-1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .padding(.horizontal, 24)
    }

    // MARK: - Step Flow

    private var stepFlow: some View {
        VStack(spacing: 0) {
            flowStep(
                icon: "camera.fill",
                color: Theme.onboardingCapture,
                title: "Capture anything",
                subtitle: "Snap food, objects, or scenes",
                iconScale: step1IconScale
            )
            .opacity(step1Visible ? 1 : 0)
            .offset(y: step1Visible ? 0 : 14)

            flowConnector(visible: connector1Visible)

            flowStep(
                icon: "wand.and.stars",
                color: Theme.visual,
                title: "AI transforms it",
                subtitle: "Into a gourmet concept dish",
                iconScale: step2IconScale
            )
            .opacity(step2Visible ? 1 : 0)
            .offset(y: step2Visible ? 0 : 14)

            flowConnector(visible: connector2Visible)

            flowStep(
                icon: "fork.knife",
                color: Theme.onboardingResult,
                title: "Get your recipe",
                subtitle: "With ingredients + visuals",
                iconScale: step3IconScale
            )
            .opacity(step3Visible ? 1 : 0)
            .offset(y: step3Visible ? 0 : 14)
        }
    }

    private func flowStep(icon: String, color: Color, title: String, subtitle: String, iconScale: CGFloat = 1.0) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
                .scaleEffect(iconScale)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.darkTextPrimary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkTextSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.cardElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    private func flowConnector(visible: Bool) -> some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.gold.opacity(0.4))
                    .frame(width: 3, height: 3)
                    .opacity(visible ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.2).delay(Double(index) * 0.1),
                        value: visible
                    )
            }
        }
        .frame(height: 18)
        .padding(.leading, 34) // Align with icon center
    }

    // MARK: - Welcome CTA

    private func welcomeCTAButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Start Creating")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.darkBg)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Theme.gold, Theme.primary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Theme.gold.opacity(0.3), radius: ctaGlowRadius, y: 4)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Chef Page

    private var chefPage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header — gold serif title
            VStack(spacing: 10) {
                Text("Choose Your Chef")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.gold)

                Text("Pick who's cooking for you. You can switch anytime.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .multilineTextAlignment(.center)

                Text("Your chef shapes the style, ingredients, and personality of every recipe.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.gold.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .opacity(chefHeaderVisible ? 1 : 0)
            .offset(y: chefHeaderVisible ? 0 : 16)

            // Chef cards
            VStack(spacing: 14) {
                ForEach(Array(ChefPersonality.allCases.filter { $0 != .custom }.enumerated()), id: \.element.id) { index, chef in
                    chefCard(chef)
                        .opacity(chefCardVisible[index] ? 1 : 0)
                        .offset(y: chefCardVisible[index] ? 0 : 20)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // CTA — "Choose Chef"
            Button {
                advance()
            } label: {
                Text("Choose Chef")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.darkBg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Theme.gold, Theme.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Theme.gold.opacity(0.35), radius: 14, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(chefCTAVisible ? 1 : 0)
            .offset(y: chefCTAVisible ? 0 : 12)
        }
        .onAppear { triggerChefAnimations() }
    }

    private func chefCard(_ chef: ChefPersonality) -> some View {
        let isSelected = selectedChef == chef.rawValue

        return Button {
            HapticManager.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedChef = chef.rawValue
            }
        } label: {
            HStack(spacing: 0) {
                // Avatar — image with SF Symbol fallback
                chefAvatar(chef, isSelected: isSelected)
                    .padding(.trailing, 14)

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(chef.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSelected ? Theme.darkTextPrimary : Theme.darkTextPrimary.opacity(0.85))

                    Text(chef.subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextSecondary)

                    if isSelected {
                        Text(chef.tagline)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.darkTextTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.gold)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Theme.glassCardFill : Theme.glassCardFill.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? Theme.gold : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            // Gold glow on selected card
            .shadow(
                color: isSelected ? Theme.gold.opacity(0.25) : .clear,
                radius: isSelected ? 12 : 0,
                y: 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .opacity(isSelected ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chef Avatar

    private func chefAvatar(_ chef: ChefPersonality, isSelected: Bool) -> some View {
        Group {
            if let uiImage = UIImage(named: chef.avatarImageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                // SF Symbol fallback
                Image(systemName: chef.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextTertiary)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Theme.gold.opacity(0.15) : Theme.darkSurface)
                    )
            }
        }
        .offset(y: isSelected && !reduceMotion ? avatarFloat : 0)
    }

    // MARK: - Preferences Page

    private func triggerPrefsAnimations() {
        guard !reduceMotion else {
            prefsHeaderVisible = true; prefsSkillVisible = true
            prefsDietaryVisible = true; prefsCTAVisible = true
            return
        }
        withAnimation(.easeOut(duration: 0.5)) { prefsHeaderVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.45)) { prefsSkillVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.45)) { prefsDietaryVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) { prefsCTAVisible = true }
        }
    }

    private var preferencesPage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 10) {
                Text("Your Preferences")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.gold)

                Text("Help us tailor recipes to your experience level and dietary needs.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .opacity(prefsHeaderVisible ? 1 : 0)
            .offset(y: prefsHeaderVisible ? 0 : 16)

            // Skill level cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Cooking Experience")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .padding(.leading, 4)

                VStack(spacing: 10) {
                    skillLevelCard(id: "beginner", icon: "leaf", title: "Beginner", subtitle: "Simple recipes, basic techniques", color: Theme.visual)
                    skillLevelCard(id: "homeCook", icon: "frying.pan", title: "Home Cook", subtitle: "Comfortable in the kitchen", color: Theme.gold)
                    skillLevelCard(id: "adventurous", icon: "flame", title: "Adventurous", subtitle: "Bring on the challenge", color: Theme.culinary)
                }
            }
            .padding(.horizontal, 20)
            .opacity(prefsSkillVisible ? 1 : 0)
            .offset(y: prefsSkillVisible ? 0 : 16)

            // Dietary preferences
            VStack(alignment: .leading, spacing: 8) {
                Text("Dietary Preferences")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .padding(.leading, 4)

                OnboardingDietarySection(selected: $selectedDietaryPrefs)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.glassCardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                Text("Active restrictions apply to all generated recipes")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextHint)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .opacity(prefsDietaryVisible ? 1 : 0)
            .offset(y: prefsDietaryVisible ? 0 : 16)

            Spacer()

            // CTA
            VStack(spacing: 12) {
                Button {
                    advance()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.darkBg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [Theme.gold, Theme.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Theme.gold.opacity(0.35), radius: 14, y: 5)
                }

                Button {
                    advance()
                } label: {
                    Text("Skip for now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.darkTextTertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(prefsCTAVisible ? 1 : 0)
            .offset(y: prefsCTAVisible ? 0 : 12)
        }
        .onAppear { triggerPrefsAnimations() }
    }

    private func skillLevelCard(id: String, icon: String, title: String, subtitle: String, color: Color) -> some View {
        let isSelected = userSkillLevel == id

        return Button {
            HapticManager.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                userSkillLevel = id
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? color : Theme.darkTextTertiary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? color.opacity(0.15) : Theme.darkSurface)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.darkTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.darkTextSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Theme.glassCardFill : Theme.glassCardFill.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Camera Page

    @State private var cameraIconScale: CGFloat = 0.95

    private var cameraPage: some View {
        VStack(spacing: 32) {
            Spacer()

            // Camera icon with sonar rings
            ZStack {
                // Sonar ring 1
                if !reduceMotion {
                    Circle()
                        .stroke(Theme.visual.opacity(ring1Opacity), lineWidth: 1)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ring1Scale)

                    Circle()
                        .stroke(Theme.visual.opacity(ring2Opacity), lineWidth: 1)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ring2Scale)
                }

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundStyle(Theme.visual)
                    .scaleEffect(cameraIconVisible ? cameraIconScale : 0.6)
                    .opacity(cameraIconVisible ? 1 : 0)
                    .onAppear {
                        guard !reduceMotion else { return }
                        // Start breathing pulse after entrance
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                                cameraIconScale = 1.05
                            }
                        }
                    }
            }

            VStack(spacing: 10) {
                Text("Enable Your Camera")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .opacity(cameraTextVisible ? 1 : 0)
                    .offset(y: cameraTextVisible ? 0 : 14)

                Text("Taste The Lens needs your camera to capture the world around you.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(cameraTextVisible ? 1 : 0)
                    .offset(y: cameraTextVisible ? 0 : 14)

                Text("Photos are analyzed by AI and never stored on our servers.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .opacity(cameraText2Visible ? 1 : 0)
                    .offset(y: cameraText2Visible ? 0 : 14)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 16) {
                ctaButton("Enable Camera") {
                    Task {
                        await AVCaptureDevice.requestAccess(for: .video)
                        dismiss()
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("I'll do this later")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.darkTextTertiary)
                }
            }
            .opacity(cameraCTAVisible ? 1 : 0)
            .offset(y: cameraCTAVisible ? 0 : 12)
        }
        .onAppear { triggerCameraAnimations() }
    }

    // MARK: - Shared CTA Button

    private func ctaButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.darkBg)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.gold)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}
