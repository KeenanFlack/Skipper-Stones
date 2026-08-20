# Pebble Skip

A calm, minimalist iOS pebble-skipping prototype built with SwiftUI and SpriteKit.

## Requirements

- Xcode 16+
- iOS 17+
- macOS Sonoma or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project

## Run it

```sh
xcodegen generate
open SkipperStones.xcodeproj
```

Select an iPhone simulator and run. The game opens directly into the Pool region.

## Controls

- Touch and hold anywhere, then pull down and left. The capped line and arc dots preview power and direction.
- Release to throw. A typical Pool throw produces several automatic skips.
- Tap during flight for a small, limited lift. Later regions allow more lifts.
- If the pebble settles on an islet, pull and release again. Otherwise use **Try Again** after the result appears; the game also restarts automatically after eight seconds.

Best distance, longest skip chain, and the most recently reached region are stored with `UserDefaults`.

## Project layout

- `App/` — SwiftUI app entry point and root view
- `Game/GameModels.swift` — centralized tuning constants, deterministic pebble state, palettes, and region profiles
- `Game/GameScene.swift` — input, fixed-step flight/skip loop, camera, generated scenery, UI, persistence, and restart flow
- `Resources/` — app metadata
- `project.yml` — reproducible XcodeGen project definition

## Next milestones

1. Tune pull distance, bounce retention, and islet frequency on several real iPhone sizes.
2. Decide whether midair lift should remain a tap or become a tiny directional gesture.
3. Add sound and restrained haptics only after the silent loop feels right.
4. Add progression systems only if they support the journey instead of crowding it.

## Architecture notes

`ContentView` remains only a SpriteKit host. The prototype intentionally keeps its complete game loop in `GameScene`; split rendering and simulation further only if v1 playtesting justifies a larger production structure.
