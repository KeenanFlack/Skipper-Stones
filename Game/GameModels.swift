import CoreGraphics
import SpriteKit

enum GameTuning {
    // Input
    static let maximumPull: CGFloat = 150
    static let minimumThrowSpeed: CGFloat = 330
    static let maximumThrowSpeed: CGFloat = 720
    static let minimumLaunchAngle: CGFloat = 10 * .pi / 180
    static let maximumLaunchAngle: CGFloat = 56 * .pi / 180

    // Flight
    static let gravity: CGFloat = -620
    static let fixedPhysicsStep: TimeInterval = 1.0 / 120.0
    static let maximumFrameDelta: TimeInterval = 1.0 / 15.0
    static let pebbleRadius: CGFloat = 9
    static let midairLift: CGFloat = 58

    // World
    static let pointsPerMeter: CGFloat = 10
    static let regionLength: CGFloat = 2_800
    static let regionBlendLength: CGFloat = 520
    static let worldChunkLength: CGFloat = 560

    // Flow
    static let minimumEnergyToSkip: CGFloat = 0.20
    static let failurePause: TimeInterval = 0.72
    static let automaticRestartDelay: TimeInterval = 8
    static let restartFlashDuration: TimeInterval = 3
}

struct PebblePhysics {
    var position: CGPoint = .zero
    var velocity: CGVector = .zero
    var gravity: CGFloat = GameTuning.gravity
    var height: CGFloat = 0
    var horizontalTravel: CGFloat = 0
    var bounceCount: Int = 0
    var remainingEnergy: CGFloat = 1
    var currentSkipChain: Int = 0
    var maximumHeight: CGFloat = 0

    mutating func beginFlight(from worldPosition: CGPoint, velocity launchVelocity: CGVector) {
        position = worldPosition
        velocity = launchVelocity
        height = worldPosition.y
        horizontalTravel = 0
        bounceCount = 0
        remainingEnergy = 1
        currentSkipChain = 0
        maximumHeight = height
    }
}

enum WaterRegion: Int, CaseIterable {
    case pool
    case lake
    case ocean

    var name: String {
        switch self {
        case .pool: return "THE POOL"
        case .lake: return "THE LAKE"
        case .ocean: return "THE OCEAN"
        }
    }

    var subtitle: String {
        switch self {
        case .pool: return "garden water"
        case .lake: return "open quiet"
        case .ocean: return "beyond the shore"
        }
    }

    var skyColor: SKColor {
        switch self {
        case .pool: return SKColor(red: 0.72, green: 0.75, blue: 0.72, alpha: 1)
        case .lake: return SKColor(red: 0.48, green: 0.50, blue: 0.67, alpha: 1)
        case .ocean: return SKColor(red: 0.23, green: 0.31, blue: 0.48, alpha: 1)
        }
    }

    var waterColor: SKColor {
        switch self {
        case .pool: return SKColor(red: 0.24, green: 0.55, blue: 0.57, alpha: 1)
        case .lake: return SKColor(red: 0.25, green: 0.39, blue: 0.58, alpha: 1)
        case .ocean: return SKColor(red: 0.08, green: 0.23, blue: 0.40, alpha: 1)
        }
    }

    var silhouetteColor: SKColor {
        switch self {
        case .pool: return SKColor(red: 0.30, green: 0.42, blue: 0.35, alpha: 1)
        case .lake: return SKColor(red: 0.22, green: 0.29, blue: 0.40, alpha: 1)
        case .ocean: return SKColor(red: 0.10, green: 0.17, blue: 0.28, alpha: 1)
        }
    }

    var accentColor: SKColor {
        switch self {
        case .pool: return SKColor(red: 0.85, green: 0.83, blue: 0.65, alpha: 1)
        case .lake: return SKColor(red: 0.75, green: 0.70, blue: 0.82, alpha: 1)
        case .ocean: return SKColor(red: 0.86, green: 0.79, blue: 0.63, alpha: 1)
        }
    }

    var bounceRetention: CGFloat {
        switch self {
        case .pool: return 0.75
        case .lake: return 0.79
        case .ocean: return 0.83
        }
    }

    var horizontalRetention: CGFloat {
        switch self {
        case .pool: return 0.90
        case .lake: return 0.915
        case .ocean: return 0.93
        }
    }

    var liftFromSpeed: CGFloat {
        switch self {
        case .pool: return 0.18
        case .lake: return 0.20
        case .ocean: return 0.23
        }
    }

    var waveAmplitude: CGFloat {
        switch self {
        case .pool: return 0.8
        case .lake: return 2.8
        case .ocean: return 6.0
        }
    }

    var allowedCorrections: Int {
        switch self {
        case .pool: return 1
        case .lake: return 2
        case .ocean: return 3
        }
    }

    static func at(worldX: CGFloat) -> WaterRegion {
        let rawIndex = max(0, Int(floor(worldX / GameTuning.regionLength)))
        return WaterRegion(rawValue: min(rawIndex, WaterRegion.allCases.count - 1)) ?? .ocean
    }
}

struct RegionBlend {
    let current: WaterRegion
    let next: WaterRegion
    let amount: CGFloat

    static func at(worldX: CGFloat) -> RegionBlend {
        let current = WaterRegion.at(worldX: worldX)
        guard current != .ocean,
              let next = WaterRegion(rawValue: current.rawValue + 1) else {
            return RegionBlend(current: current, next: current, amount: 0)
        }

        let regionStart = CGFloat(current.rawValue) * GameTuning.regionLength
        let transitionStart = regionStart + GameTuning.regionLength - GameTuning.regionBlendLength
        let amount = min(1, max(0, (worldX - transitionStart) / GameTuning.regionBlendLength))
        return RegionBlend(current: current, next: next, amount: amount)
    }
}

extension SKColor {
    static func blended(from first: SKColor, to second: SKColor, amount: CGFloat) -> SKColor {
        let t = min(1, max(0, amount))
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}
