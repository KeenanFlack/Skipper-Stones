# Skipper Stones

An iOS rock-skipping game prototype built with SwiftUI and SpriteKit.

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

Select an iPhone simulator and run. Drag from the stone toward the water and release to throw. The current prototype scores bounces and tracks the best score locally.

## Project layout

- `App/` — SwiftUI app entry point and root view
- `Game/` — SpriteKit scene, input handling, physics, scoring, and game state
- `Resources/` — asset catalog and app metadata
- `project.yml` — reproducible XcodeGen project definition

## Next milestones

1. Tune the throw curve and water-bounce feel on device.
2. Add stone selection and a simple progression loop.
3. Add sound, haptics, and a camera/shoreline art pass.
4. Add Game Center leaderboards and analytics only after the core loop feels good.

## Architecture notes

`GameScene` is intentionally small and owns only game-world concerns. `ContentView` is the app shell and can later host menus, settings, and progression screens without coupling them to SpriteKit physics.
