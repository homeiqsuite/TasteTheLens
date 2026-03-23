import SwiftUI
import AVFoundation

enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case chef = 1
    case dietary = 2
    case camera = 3
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("selectedChef") private var selectedChef = "default"

    @State private var currentPage: OnboardingPage = .welcome
    @State private var showContent = false
    @State private var selectedDietary: Set<DietaryPreference> = Set(DietaryPreference.current())

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
                    case .dietary:
                        dietaryPage
                            .transition(pageTransition)
                    case .camera:
                        cameraPage
                            .transition(pageTransition)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                Capsule()
                    .fill(page == currentPage ? Theme.gold : Theme.darkStroke)
                    .frame(width: page == currentPage ? 24 : 8, height: 8)
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
        let next = OnboardingPage(rawValue: currentPage.rawValue + 1)
        if let next {
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

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon
            Image("AppIcon")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            // Title + tagline
            VStack(spacing: 10) {
                Text("Taste The Lens")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.gold)

                Text("What does the world taste like?")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.darkTextSecondary)
            }

            // Value props
            VStack(spacing: 12) {
                valueProp(icon: "camera.fill", color: Theme.visual, text: "Photograph anything around you")
                valueProp(icon: "wand.and.stars", color: Theme.gold, text: "AI translates it into haute cuisine")
                valueProp(icon: "fork.knife", color: Theme.culinary, text: "Get a complete recipe with food photography")
            }
            .padding(.horizontal, 24)

            Spacer()

            ctaButton("Get Started") { advance() }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }

    private func valueProp(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.darkTextPrimary)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.glassCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.darkStroke, lineWidth: 0.5)
        )
    }

    // MARK: - Chef Page

    private var chefPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 10) {
                Text("Choose Your Chef")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)

                Text("Pick who's cooking for you. You can switch anytime.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                ForEach(ChefPersonality.allCases) { chef in
                    chefOption(chef)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            ctaButton("Continue") { advance() }
        }
    }

    private func chefOption(_ chef: ChefPersonality) -> some View {
        let isSelected = selectedChef == chef.rawValue

        return Button {
            HapticManager.light()
            selectedChef = chef.rawValue
        } label: {
            HStack(spacing: 14) {
                Image(systemName: chef.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextTertiary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? Theme.gold.opacity(0.15) : Theme.darkSurface)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(chef.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text(chef.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.gold)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.glassCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.gold : Theme.darkStroke, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: selectedChef)
    }

    // MARK: - Dietary Page

    private var dietaryPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 10) {
                Text("Any Dietary Needs?")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)

                Text("We'll tailor every recipe. Skip if none apply.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            OnboardingDietarySection(selected: $selectedDietary)
                .padding(.horizontal, 24)

            Spacer()

            ctaButton("Continue") {
                DietaryPreference.save(Array(selectedDietary))
                advance()
            }
        }
    }

    // MARK: - Camera Page

    @State private var cameraIconScale: CGFloat = 0.95

    private var cameraPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(Theme.visual)
                .scaleEffect(cameraIconScale)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        cameraIconScale = 1.05
                    }
                }

            VStack(spacing: 10) {
                Text("One Last Thing")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)

                Text("Taste The Lens needs your camera to capture the world around you.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .multilineTextAlignment(.center)

                Text("Photos are analyzed by AI and never stored on our servers.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
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
        }
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
