# TasteTheLens

iOS app that translates visual imagery into haute cuisine recipes using AI. Users photograph anything and the app generates a complete culinary recipe inspired by the visual elements, along with an AI-generated food photography image.

## Architecture

- **Platform:** iOS (SwiftUI + SwiftData), deployment target iOS 26.2
- **Bundle ID:** `com.eightgates.Taste-The-Lens`
- **No third-party dependencies** — uses only Apple frameworks (AVFoundation, SwiftData, SwiftUI)

### Project Structure

```
Taste The Lens/Taste The Lens/
├── Taste_The_LensApp.swift        # App entry, SwiftData container
├── ContentView.swift              # Main navigation (camera → processing → recipe)
├── Config/                        # API key loading (AppConfig.swift, Secrets.xcconfig)
├── Camera/                        # AVFoundation camera (CameraManager, CameraPreviewView)
├── Models/Recipe.swift            # SwiftData @Model + supporting Codable structs
├── Services/                      # API clients + pipeline orchestration
│   ├── ImageAnalysisPipeline.swift  # Observable pipeline: analyze → generate
│   ├── GeminiAPIClient.swift        # Primary: Gemini 2.5 Flash
│   ├── ClaudeAPIClient.swift        # Alternative: Claude Sonnet
│   └── FalAPIClient.swift           # Image gen: Flux Pro v1.1
├── Views/
│   ├── CameraView.swift
│   ├── ProcessingView.swift
│   ├── RecipeCardView.swift
│   ├── SavedRecipesView.swift
│   ├── SplashView.swift
│   ├── SideBySideExportView.swift   # Share card (ImageRenderer only)
│   └── Components/                  # ShutterButton, GlassCard, ProcessingAnimations
└── Extensions/UIImage+Resize.swift  # Image compression for API uploads
```

### User Flow

1. **CameraView** — Capture a photo of anything
2. **ProcessingView** — AR-style overlay with animated color swatches while pipeline runs
3. **RecipeCardView** — Full recipe display with hero image, translation matrix, components, instructions, pairings
4. **SavedRecipesView** — Browse saved recipes (SwiftData persistence)

### API Pipeline (ImageAnalysisPipeline)

1. Analyze image with Gemini (or Claude) → returns recipe JSON
2. Generate dish image with Fal.ai Flux Pro → returns food photo
3. Transition to RecipeCardView

## UI Conventions

### Color Palette (Dark Theme)

- Background: `#0D0D0F`
- Gold accent: `#C9A84C`
- Cyan (visual elements): `#64D2FF`
- Coral (culinary elements): `#FF6B6B`

### Fill Images — Use the Overlay Pattern

**Never** use `.aspectRatio(contentMode: .fill)` directly on an image with `.clipped()`. The `.clipped()` modifier only clips rendering, NOT layout — the image will inflate its parent's layout size and push content off-screen.

Instead, use the overlay pattern:

```swift
// WRONG — layout expands beyond screen bounds
Image(uiImage: image)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(height: 280)
    .clipped()

// CORRECT — layout stays bounded
Color.clear
    .frame(height: 280)
    .overlay {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16))
```

**Exception:** Images with explicit width AND height (e.g., `.frame(width: 60, height: 60)`) are fine with `.fill` directly since both dimensions are constrained.

**Exception:** Off-screen rendering (e.g., `SideBySideExportView` used only with `ImageRenderer`) doesn't need this pattern.

### Glass Card Modifier

Use `.glassCard()` for card-style sections. It adds horizontal/vertical padding internally (16px/20px), so don't double-pad.

### Previews

Add `#Preview` blocks to views for rapid iteration. For views needing Recipe data, create mock data with `UIGraphicsImageRenderer` for placeholder images and an in-memory `ModelContainer`.

## Credentials

API keys are loaded from `Secrets.xcconfig` (git-ignored) → `Info.plist` → `AppConfig.swift`. Keys needed:
- `GEMINI_API_KEY`
- `FAL_API_KEY`
- `ANTHROPIC_API_KEY` (optional, for Claude alternative)

## Logging

Uses `os.Logger` with subsystem `com.eightgates.TasteTheLens` and per-file categories (ContentView, Pipeline, CameraView, etc.).
