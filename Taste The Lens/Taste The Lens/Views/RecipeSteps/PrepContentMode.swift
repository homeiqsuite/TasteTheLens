import SwiftUI

enum PrepContentMode: String, CaseIterable, Identifiable {
    case quickStart
    case storyMode
    case aiBreakdown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quickStart: return "Quick Start"
        case .storyMode: return "Story Mode"
        case .aiBreakdown: return "AI Breakdown"
        }
    }

    var icon: String {
        switch self {
        case .quickStart: return "bolt.fill"
        case .storyMode: return "book.fill"
        case .aiBreakdown: return "cpu"
        }
    }
}

struct PrepModePicker: View {
    @Binding var selectedMode: PrepContentMode
    var hasTranslationMatrix: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PrepContentMode.allCases) { mode in
                let isSelected = selectedMode == mode
                let isDisabled = mode == .aiBreakdown && !hasTranslationMatrix

                Button {
                    HapticManager.selection()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(mode.label)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSelected ? Theme.primary : Theme.primary.opacity(0.08))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : Theme.primary.opacity(0.25), lineWidth: 0.5)
                    )
                    .foregroundStyle(isSelected ? Theme.darkTextPrimary : Theme.primary)
                    .opacity(isDisabled ? 0.4 : 1)
                }
                .disabled(isDisabled)
            }
        }
    }
}
