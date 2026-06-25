import SwiftUI

/// The three primary home destinations.
enum AppTab: String, CaseIterable {
    case home, saved, profile

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .saved: return "bookmark.fill"
        case .profile: return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .saved: return "Saved"
        case .profile: return "Profile"
        }
    }
}

/// Floating pill tab bar + circular camera FAB.
///
/// The active tab expands to show its label inside an accent-tinted capsule;
/// inactive tabs collapse to just an icon. The FAB launches the camera.
struct BottomTabBar: View {
    @Binding var selection: AppTab
    let theme: ChefTheme
    let onCamera: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            tabPill
            cameraFAB
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Tab Pill

    private var tabPill: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous).fill(theme.cardBg)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(theme.cardBorder.opacity(0.6), lineWidth: DS.Stroke.hairline)
        )
        .shadow(color: theme.cardShadow, radius: 12, x: 0, y: 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selection == tab
        return Button {
            guard !isActive else { return }
            HapticManager.light()
            selection = tab
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .semibold))
                if isActive {
                    Text(tab.label)
                        .font(.dsMicro)
                        .fixedSize()
                }
            }
            .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Camera FAB

    private var cameraFAB: some View {
        Button {
            HapticManager.medium()
            onCamera()
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(theme.ctaGradient))
                .shadow(color: theme.accent.opacity(0.35), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New recipe from camera")
    }
}

#Preview("Bottom Tab Bar") {
    @Previewable @State var selection: AppTab = .home
    ZStack(alignment: .bottom) {
        ChefTheme.defaultChef.dashboardBg.ignoresSafeArea()
        BottomTabBar(selection: $selection, theme: .defaultChef, onCamera: {})
            .padding(.bottom, 8)
    }
}
