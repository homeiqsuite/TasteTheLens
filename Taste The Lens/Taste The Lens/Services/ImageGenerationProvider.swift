import Foundation

// MARK: - Model Selection

enum ImageGenerationModel: String, CaseIterable, Identifiable {
    case fluxPro = "flux-pro"
    case fluxSchnell = "flux-schnell"
    case imagen4 = "imagen-4"
    case imagen4Fast = "imagen-4-fast"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fluxPro: return "Flux Pro v1.1"
        case .fluxSchnell: return "Flux Schnell"
        case .imagen4: return "Imagen 4"
        case .imagen4Fast: return "Imagen 4 Fast"
        }
    }

    var provider: String {
        switch self {
        case .fluxPro, .fluxSchnell: return "Fal.ai"
        case .imagen4, .imagen4Fast: return "Google"
        }
    }

    var estimatedCost: String {
        switch self {
        case .fluxPro: return "~$0.050"
        case .fluxSchnell: return "~$0.003"
        case .imagen4: return "~$0.030"
        case .imagen4Fast: return "~$0.020"
        }
    }

    var qualityTier: String {
        switch self {
        case .fluxPro: return "Highest"
        case .imagen4: return "High"
        case .imagen4Fast: return "Good"
        case .fluxSchnell: return "Standard"
        }
    }
}
