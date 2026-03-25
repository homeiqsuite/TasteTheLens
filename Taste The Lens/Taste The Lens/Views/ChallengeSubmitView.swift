import SwiftUI
import PhotosUI
import os

private let logger = makeLogger(category: "ChallengeSubmit")

struct ChallengeSubmitView: View {
    let challenge: ChallengeDTO
    var onSubmit: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var caption = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var referenceImage: UIImage?

    private let challengeService = ChallengeService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        instructionText

                        // Side-by-side: reference vs user photo
                        sideBySideSection

                        // Photo picker
                        photoPickerSection

                        // Caption
                        captionField

                        // Submit
                        submitButton

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Submit Your Attempt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .task {
                if let path = challenge.dishImagePath, !path.isEmpty {
                    referenceImage = await challengeService.loadImage(path: path)
                }
            }
        }
    }

    private var instructionText: some View {
        Text("Cook **\(challenge.title)** and photograph your real version")
            .font(.system(size: 15))
            .foregroundStyle(Theme.darkTextSecondary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Side by Side

    private var sideBySideSection: some View {
        HStack(spacing: 12) {
            // AI Reference
            VStack(spacing: 6) {
                Color.clear
                    .frame(height: 150)
                    .overlay {
                        if let image = referenceImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Theme.darkSurface)
                                .overlay {
                                    ProgressView().tint(Theme.gold)
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("AI Reference")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.darkTextTertiary)
            }

            // User Photo
            VStack(spacing: 6) {
                Color.clear
                    .frame(height: 150)
                    .overlay {
                        if let data = selectedImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Theme.darkSurface)
                                .overlay {
                                    VStack(spacing: 6) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 24))
                                        Text("Your Photo")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundStyle(Theme.darkTextHint)
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Your Attempt")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.darkTextTertiary)
            }
        }
    }

    // MARK: - Photo Picker

    private var photoPickerSection: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                Text(selectedImageData == nil ? "Choose Photo" : "Change Photo")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Theme.gold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
            )
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }

    // MARK: - Caption

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Caption (optional)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.darkTextTertiary)

            TextField("How did it turn out?", text: $caption)
                .font(.system(size: 15))
                .foregroundStyle(Theme.darkTextPrimary)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.darkSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.darkStroke, lineWidth: 0.5)
                )
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(Theme.darkBg)
                }
                Text(isSubmitting ? "Submitting..." : "Submit")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Theme.darkBg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedImageData != nil ? Theme.gold : Theme.gold.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedImageData == nil || isSubmitting)
    }

    private func submit() async {
        guard let photoData = selectedImageData else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            // Compress image
            let compressed: Data
            if let uiImage = UIImage(data: photoData),
               let jpeg = uiImage.jpegData(compressionQuality: 0.8) {
                compressed = jpeg
            } else {
                compressed = photoData
            }

            try await challengeService.submitAttempt(
                challengeId: challenge.id,
                photoData: compressed,
                caption: caption.isEmpty ? nil : caption
            )
            HapticManager.success()
            onSubmit()
            dismiss()
        } catch {
            logger.error("Submission failed: \(error)")
            errorMessage = error.localizedDescription
            isSubmitting = false
        }
    }
}
