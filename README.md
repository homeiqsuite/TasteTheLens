# TasteTheLens

iOS app that translates visual imagery into haute cuisine recipes using AI. Users photograph anything and the app generates a complete culinary recipe inspired by the visual elements, along with an AI-generated food photography image.

## Requirements

- Xcode 26.3+
- iOS 26.2 deployment target
- API keys configured in `Taste The Lens/Taste The Lens/Config/Secrets.xcconfig` (see `Secrets.xcconfig.example`)

## Build Schemes

| Scheme | Purpose |
|--------|---------|
| **Taste The Lens** | Default development scheme (Debug config). Logging and debug menu enabled. |
| **TasteTheLens-Production** | Production scheme. All logging disabled, developer debug menu hidden. |

## Version Bump

Version is managed via `Taste The Lens/Taste The Lens/Config/Version.xcconfig` (single source of truth).

Run from the `development` branch with a clean working tree:

```bash
cd "Taste The Lens"
./Scripts/version-bump.sh patch   # 1.0.0 → 1.0.1
./Scripts/version-bump.sh minor   # 1.0.0 → 1.1.0
./Scripts/version-bump.sh major   # 1.0.0 → 2.0.0
```

The script will:
1. Validate you're on `development` with no uncommitted changes
2. Read the current version from `Version.xcconfig`
3. Create a `release/vX.X.X` branch
4. Update the version, commit, and create an annotated git tag

Then push when ready:
```bash
git push origin release/vX.X.X
git push origin vX.X.X
```
