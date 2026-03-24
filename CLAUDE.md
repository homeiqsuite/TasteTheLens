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

### Color Design Reference

- [MobileColorDesign.md](MobileColorDesign.md) — Principles for choosing colors in mobile apps (color psychology, the "Fourth C" of design, and best practices).
- [ColorTheory.md](ColorTheory.md) — Color theory fundamentals (the color wheel, color properties, and six color harmonies).

### Color Palette — iOS App (Dark Theme, Analogous Warm + Cool Complement)

- Background: `#0D0D0F`
- Gold (brand identity, decorative emphasis): `#D4A43A`
- Primary (interactive elements, buttons): `#B89530`
- Visual (photography/scene analysis domain): `#3A9E8F` (teal)
- Culinary (cooking/recipe domain): `#C86B50` (terracotta)

### Color Palette — Landing Page Website (Dark Theme, Warm/Cool Harmony)

Defined as CSS custom properties in `LandingPage/styles.css`.

**Backgrounds:**
- `--bg`: `#0A0A12` (primary dark background)
- `--bg-alt`: `#13101E` (alternative dark background)
- `--bg-warm`: `#1A1530` (warm dark background)

**Brand & Accent:**
- `--gold` / `--primary`: `#E8A832` (primary accent, brand color)
- `--gold-dim`: `#A07520` (dimmed gold)
- `--purple`: `#7B3FA0` (secondary accent)
- `--purple-bright`: `#9B5FC0` (bright purple)
- `--magenta`: `#C73B8E` (accent color)

**Text:**
- `--text-primary`: `#F0ECF5`
- `--text-secondary`: `#C8BFD6`
- `--text-muted`: `#9B8FB5`
- `--text-dim`: `#6B5F80`

**Components:**
- `--card-bg`: `rgba(35, 28, 58, 0.95)`
- `--card-border`: `rgba(123, 63, 160, 0.35)`

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

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update tasks/lessons.md with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes -- don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests -- then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to tasks/todo.md with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to tasks/todo.md
6. **Capture Lessons**: Update tasks/lessons.md after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Only touch what's necessary. No side effects with new bugs.
