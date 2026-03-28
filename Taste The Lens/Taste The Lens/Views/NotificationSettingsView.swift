import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var pushService = PushNotificationService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // System permission status
                systemPermissionSection

                // Per-category toggles
                if pushService.permissionStatus == .authorized {
                    categorySection
                }

                Spacer().frame(height: 40)
            }
            .padding(.top, 20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await pushService.refreshPermissionStatus()
        }
    }

    // MARK: - System Permission

    @ViewBuilder
    private var systemPermissionSection: some View {
        settingsSection("System") {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.system(size: 15))
                    .foregroundStyle(statusColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Push Notifications")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(statusDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                if pushService.permissionStatus == .denied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Settings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .stroke(Theme.primary, lineWidth: 1)
                            )
                    }
                } else if pushService.permissionStatus == .notDetermined {
                    Button {
                        Task { await pushService.requestPermission() }
                    } label: {
                        Text("Enable")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .stroke(Theme.primary, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Category Toggles

    @ViewBuilder
    private var categorySection: some View {
        settingsSection("Categories") {
            VStack(spacing: 0) {
                preferenceToggle(
                    "Challenge Activity",
                    subtitle: "Submissions and upvotes on your challenges",
                    icon: "flame",
                    isOn: Binding(
                        get: { pushService.preferences.challengeActivity },
                        set: { newValue in
                            pushService.preferences.challengeActivity = newValue
                            Task { await pushService.savePreferences() }
                        }
                    )
                )

                settingsDivider

                preferenceToggle(
                    "Tasting Menu Updates",
                    subtitle: "Invitations and new courses added",
                    icon: "menucard",
                    isOn: Binding(
                        get: { pushService.preferences.tastingMenuUpdates },
                        set: { newValue in
                            pushService.preferences.tastingMenuUpdates = newValue
                            Task { await pushService.savePreferences() }
                        }
                    )
                )

                settingsDivider

                preferenceToggle(
                    "Weekly Inspiration",
                    subtitle: "Creative nudges and seasonal challenges",
                    icon: "sparkles",
                    isOn: Binding(
                        get: { pushService.preferences.weeklyInspiration },
                        set: { newValue in
                            pushService.preferences.weeklyInspiration = newValue
                            Task { await pushService.savePreferences() }
                        }
                    )
                )
            }
        }
    }

    // MARK: - Helpers

    private func preferenceToggle(_ title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(Theme.primary)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.horizontal, 16)

            content()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
        }
    }

    private var settingsDivider: some View {
        Divider()
            .background(Theme.divider)
            .padding(.leading, 50)
    }

    private var statusIcon: String {
        switch pushService.permissionStatus {
        case .authorized, .provisional, .ephemeral: "bell.badge.fill"
        case .denied: "bell.slash"
        case .notDetermined: "bell"
        @unknown default: "bell"
        }
    }

    private var statusColor: Color {
        switch pushService.permissionStatus {
        case .authorized, .provisional, .ephemeral: .green
        case .denied: .red
        case .notDetermined: Theme.textTertiary
        @unknown default: Theme.textTertiary
        }
    }

    private var statusDescription: String {
        switch pushService.permissionStatus {
        case .authorized, .provisional, .ephemeral: "Notifications are enabled"
        case .denied: "Notifications are disabled. Enable them in Settings."
        case .notDetermined: "Allow notifications to stay updated"
        @unknown default: "Unknown status"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
