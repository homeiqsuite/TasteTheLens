import SwiftUI
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "DebugMenu")

struct DebugMenuView: View {
    @AppStorage("debug_imageGenModel") private var selectedModelRaw = ImageGenerationModel.imagen4.rawValue
    @AppStorage("debug_processingStyle") private var selectedStyleRaw = ProcessingStyle.classic.rawValue
    @Environment(\.dismiss) private var dismiss

    private var selectedModel: ImageGenerationModel {
        get { ImageGenerationModel(rawValue: selectedModelRaw) ?? .imagen4 }
        nonmutating set { selectedModelRaw = newValue.rawValue }
    }

    private var selectedStyle: ProcessingStyle {
        get { ProcessingStyle(rawValue: selectedStyleRaw) ?? .classic }
        nonmutating set { selectedStyleRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        debugBanner

                        imageGenSection

                        processingStyleSection

                        currentConfigSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
        }
    }

    // MARK: - Debug Banner

    private var debugBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "ant")
                .font(.system(size: 18))
                .foregroundStyle(Theme.visual)
            Text("Developer Tools")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.darkTextPrimary)
            Spacer()
        }
        .padding(14)
        .background(Theme.visual.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.visual.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Image Generation Model

    private var imageGenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Image Generation Model")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(ImageGenerationModel.allCases) { model in
                modelRow(model)
            }
        }
    }

    private func modelRow(_ model: ImageGenerationModel) -> some View {
        let isSelected = selectedModel == model

        return Button {
            selectedModelRaw = model.rawValue
            logger.info("Image gen model changed to: \(model.displayName)")
            HapticManager.light()
        } label: {
            HStack(spacing: 14) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? Theme.gold : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Theme.gold : Theme.darkStroke, lineWidth: 1.5)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.darkTextPrimary)

                        Text(model.provider)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(model.provider == "Google" ? Theme.visual : Theme.culinary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (model.provider == "Google" ? Theme.visual : Theme.culinary).opacity(0.15)
                            )
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 12) {
                        Label(model.estimatedCost, systemImage: "dollarsign.circle")
                        Label(model.qualityTier, systemImage: "sparkles")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextTertiary)
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? Theme.gold.opacity(0.08) : Theme.darkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.gold.opacity(0.3) : Theme.darkStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Processing View Style

    private var processingStyleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Processing View Style")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(ProcessingStyle.allCases) { style in
                styleRow(style)
            }
        }
    }

    private func styleRow(_ style: ProcessingStyle) -> some View {
        let isSelected = selectedStyle == style

        return Button {
            selectedStyleRaw = style.rawValue
            logger.info("Processing style changed to: \(style.displayName)")
            HapticManager.light()
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(isSelected ? Theme.gold : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Theme.gold : Theme.darkStroke, lineWidth: 1.5)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: style.iconName)
                            .font(.system(size: 14))
                            .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextSecondary)
                            .frame(width: 20)

                        Text(style.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.darkTextPrimary)
                    }

                    Text(style.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.darkTextTertiary)
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? Theme.gold.opacity(0.08) : Theme.darkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.gold.opacity(0.3) : Theme.darkStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Current Config

    private var currentConfigSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Active Configuration")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                configRow(label: "Analysis Model", value: "Gemini 2.5 Flash")
                Divider().background(Theme.darkStroke)
                configRow(label: "Image Model", value: selectedModel.displayName)
                Divider().background(Theme.darkStroke)
                configRow(label: "Image Provider", value: selectedModel.provider)
                Divider().background(Theme.darkStroke)
                configRow(label: "Processing Style", value: selectedStyle.displayName)
                Divider().background(Theme.darkStroke)
                configRow(label: "Est. Cost/Gen", value: selectedModel.estimatedCost)
            }
            .background(Theme.darkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.darkStroke, lineWidth: 1)
            )
        }
    }

    private func configRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.darkTextPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#Preview {
    DebugMenuView()
}
