import SpriteKit

final class GameScene: SKScene {
    private enum PlayState: Equatable {
        case ready
        case aiming
        case flying
        case failing
        case results
    }

    private struct LandingIsland {
        let centerX: CGFloat
        let width: CGFloat
        let topHeight: CGFloat
        let node: SKShapeNode
    }

    private let cream = SKColor(red: 0.94, green: 0.91, blue: 0.79, alpha: 1)
    private let lavender = SKColor(red: 0.76, green: 0.72, blue: 0.84, alpha: 1)
    private let backgroundParallax: CGFloat = 0.24
    private let middleParallax: CGFloat = 0.56

    private let cameraNode = SKCameraNode()
    private let backgroundLayer = SKNode()
    private let middleLayer = SKNode()
    private let foregroundLayer = SKNode()
    private let effectsLayer = SKNode()
    private let waterBody = SKShapeNode()
    private let waterCrest = SKShapeNode()
    private let pebble = SKShapeNode(circleOfRadius: GameTuning.pebbleRadius)
    private let pebbleGlow = SKShapeNode(circleOfRadius: GameTuning.pebbleRadius * 1.8)
    private let aimLine = SKShapeNode()
    private var trajectoryDots: [SKShapeNode] = []

    private let distanceLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let skipLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let instructionLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let regionLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let regionSubtitleLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let correctionLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let powerTrack = SKShapeNode()
    private let powerFill = SKShapeNode()
    private let celestialNode = SKShapeNode(circleOfRadius: 30)

    private let resultPanel = SKShapeNode()
    private let resultTitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let resultDistance = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let resultChain = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let resultBest = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let tryAgainButton = SKShapeNode()
    private let tryAgainLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    private var playState: PlayState = .ready
    private var physics = PebblePhysics()
    private var islands: [LandingIsland] = []
    private var aimStart: CGPoint?
    private var aimCurrent: CGPoint?
    private var lastUpdateTime: TimeInterval = 0
    private var physicsAccumulator: TimeInterval = 0
    private var worldTime: TimeInterval = 0
    private var lastWaterDrawTime: TimeInterval = -1
    private var runStartX: CGFloat = 0
    private var flightStartX: CGFloat = 0
    private var nextChunkToGenerate = 0
    private var displayedRegion: WaterRegion?
    private var midairCorrectionsRemaining = 0
    private var runBestChain = 0
    private var landingsThisRun = 0
    private var highMomentShown = false
    private var resultShownAt: TimeInterval = 0
    private var currentCameraScale: CGFloat = 1

    private var waterSurfaceY: CGFloat { size.height * 0.27 }
    private var bestDistance = UserDefaults.standard.integer(forKey: "pebbleSkip.bestDistance")
    private var bestChain = UserDefaults.standard.integer(forKey: "pebbleSkip.bestChain")
    private var unlockedRegionIndex = min(
        WaterRegion.allCases.count - 1,
        UserDefaults.standard.integer(forKey: "pebbleSkip.unlockedRegion")
    )

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        view.isMultipleTouchEnabled = false
        view.preferredFramesPerSecond = 60
        setupScene()
        startNewRun()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard cameraNode.parent != nil else { return }
        layoutHUD()
        redrawWater(force: true)
    }

    private func setupScene() {
        removeAllChildren()

        backgroundLayer.zPosition = -40
        middleLayer.zPosition = -30
        waterBody.zPosition = -20
        waterCrest.zPosition = -19
        foregroundLayer.zPosition = -10
        effectsLayer.zPosition = 20

        addChild(backgroundLayer)
        addChild(middleLayer)
        addChild(waterBody)
        addChild(waterCrest)
        addChild(foregroundLayer)
        addChild(effectsLayer)

        waterBody.strokeColor = .clear
        waterCrest.fillColor = .clear
        waterCrest.lineWidth = 1.25

        pebble.fillColor = cream
        pebble.strokeColor = .white.withAlphaComponent(0.42)
        pebble.lineWidth = 1.2
        pebble.zPosition = 12
        pebbleGlow.fillColor = lavender.withAlphaComponent(0.12)
        pebbleGlow.strokeColor = .clear
        pebbleGlow.zPosition = -1
        pebble.addChild(pebbleGlow)
        addChild(pebble)

        aimLine.strokeColor = cream.withAlphaComponent(0.72)
        aimLine.lineWidth = 2
        aimLine.lineCap = .round
        aimLine.zPosition = 15
        aimLine.isHidden = true
        addChild(aimLine)

        for index in 0..<8 {
            let dot = SKShapeNode(circleOfRadius: max(1.6, 3.2 - CGFloat(index) * 0.18))
            dot.fillColor = cream.withAlphaComponent(0.62 - CGFloat(index) * 0.045)
            dot.strokeColor = .clear
            dot.zPosition = 14
            dot.isHidden = true
            trajectoryDots.append(dot)
            addChild(dot)
        }

        addChild(cameraNode)
        camera = cameraNode
        configureHUD()
        layoutHUD()
    }

    private func configureHUD() {
        cameraNode.zPosition = 100

        [distanceLabel, skipLabel, instructionLabel, regionLabel, regionSubtitleLabel, correctionLabel].forEach {
            $0.fontColor = cream.withAlphaComponent(0.9)
            $0.zPosition = 5
            cameraNode.addChild($0)
        }

        distanceLabel.fontSize = 13
        distanceLabel.horizontalAlignmentMode = .left
        distanceLabel.verticalAlignmentMode = .center
        distanceLabel.text = "0 m"

        skipLabel.fontSize = 13
        skipLabel.horizontalAlignmentMode = .right
        skipLabel.verticalAlignmentMode = .center
        skipLabel.text = "0 SKIPS"

        instructionLabel.fontSize = 13
        instructionLabel.horizontalAlignmentMode = .center
        instructionLabel.verticalAlignmentMode = .center

        regionLabel.fontSize = 20
        regionLabel.horizontalAlignmentMode = .center
        regionLabel.alpha = 0

        regionSubtitleLabel.fontSize = 11
        regionSubtitleLabel.horizontalAlignmentMode = .center
        regionSubtitleLabel.alpha = 0

        correctionLabel.fontSize = 11
        correctionLabel.horizontalAlignmentMode = .center
        correctionLabel.alpha = 0

        let trackPath = CGMutablePath()
        trackPath.move(to: CGPoint(x: -60, y: 0))
        trackPath.addLine(to: CGPoint(x: 60, y: 0))
        powerTrack.path = trackPath
        powerTrack.strokeColor = cream.withAlphaComponent(0.2)
        powerTrack.lineWidth = 3
        powerTrack.lineCap = .round
        powerTrack.isHidden = true
        powerTrack.zPosition = 4
        cameraNode.addChild(powerTrack)

        powerFill.strokeColor = cream.withAlphaComponent(0.82)
        powerFill.lineWidth = 3
        powerFill.lineCap = .round
        powerFill.isHidden = true
        powerFill.zPosition = 5
        cameraNode.addChild(powerFill)

        celestialNode.fillColor = cream.withAlphaComponent(0.45)
        celestialNode.strokeColor = .clear
        celestialNode.zPosition = -180
        cameraNode.addChild(celestialNode)

        configureResultPanel()
    }

    private func configureResultPanel() {
        resultPanel.path = CGPath(
            roundedRect: CGRect(x: -142, y: -138, width: 284, height: 276),
            cornerWidth: 28,
            cornerHeight: 28,
            transform: nil
        )
        resultPanel.fillColor = SKColor(red: 0.08, green: 0.14, blue: 0.22, alpha: 0.88)
        resultPanel.strokeColor = cream.withAlphaComponent(0.15)
        resultPanel.lineWidth = 1
        resultPanel.zPosition = 30
        resultPanel.isHidden = true
        cameraNode.addChild(resultPanel)

        resultTitle.text = "A GOOD JOURNEY"
        resultTitle.fontSize = 17
        resultTitle.fontColor = cream
        resultTitle.position = CGPoint(x: 0, y: 82)

        resultDistance.fontSize = 24
        resultDistance.fontColor = cream
        resultDistance.position = CGPoint(x: 0, y: 36)

        resultChain.fontSize = 14
        resultChain.fontColor = cream.withAlphaComponent(0.82)
        resultChain.position = CGPoint(x: 0, y: 5)

        resultBest.fontSize = 11
        resultBest.fontColor = cream.withAlphaComponent(0.58)
        resultBest.position = CGPoint(x: 0, y: -27)

        let buttonRect = CGRect(x: -94, y: -24, width: 188, height: 48)
        tryAgainButton.path = CGPath(
            roundedRect: buttonRect,
            cornerWidth: 24,
            cornerHeight: 24,
            transform: nil
        )
        tryAgainButton.position = CGPoint(x: 0, y: -91)
        tryAgainButton.fillColor = cream.withAlphaComponent(0.92)
        tryAgainButton.strokeColor = .clear
        tryAgainButton.name = "tryAgain"

        tryAgainLabel.text = "TRY AGAIN"
        tryAgainLabel.fontSize = 13
        tryAgainLabel.fontColor = SKColor(red: 0.12, green: 0.19, blue: 0.25, alpha: 1)
        tryAgainLabel.verticalAlignmentMode = .center
        tryAgainLabel.name = "tryAgain"
        tryAgainButton.addChild(tryAgainLabel)

        [resultTitle, resultDistance, resultChain, resultBest, tryAgainButton].forEach {
            $0.zPosition = 1
            resultPanel.addChild($0)
        }
    }

    private func layoutHUD() {
        let halfWidth = size.width * 0.5
        let halfHeight = size.height * 0.5
        distanceLabel.position = CGPoint(x: -halfWidth + 22, y: halfHeight - 50)
        skipLabel.position = CGPoint(x: halfWidth - 22, y: halfHeight - 50)
        instructionLabel.position = CGPoint(x: 0, y: -halfHeight + 43)
        powerTrack.position = CGPoint(x: 0, y: -halfHeight + 72)
        powerFill.position = powerTrack.position
        regionLabel.position = CGPoint(x: 0, y: halfHeight * 0.43)
        regionSubtitleLabel.position = CGPoint(x: 0, y: halfHeight * 0.43 - 25)
        correctionLabel.position = CGPoint(x: 0, y: -halfHeight + 93)
        celestialNode.position = CGPoint(x: halfWidth * 0.48, y: halfHeight * 0.28)
        resultPanel.position = .zero
    }

    private func startNewRun() {
        removeAllActions()
        resultPanel.isHidden = true
        resultPanel.alpha = 1
        tryAgainButton.alpha = 1
        pebble.alpha = 1
        pebble.setScale(1)
        pebble.removeAllActions()

        backgroundLayer.removeAllChildren()
        middleLayer.removeAllChildren()
        foregroundLayer.removeAllChildren()
        effectsLayer.removeAllChildren()
        islands.removeAll()

        let regionStart = CGFloat(unlockedRegionIndex) * GameTuning.regionLength
        runStartX = regionStart + 96
        flightStartX = runStartX
        runBestChain = 0
        landingsThisRun = 0
        physics = PebblePhysics()
        physics.position = CGPoint(x: runStartX, y: 22)
        physics.height = 22
        playState = .ready
        displayedRegion = nil
        midairCorrectionsRemaining = 0
        highMomentShown = false
        physicsAccumulator = 0

        nextChunkToGenerate = Int(floor((runStartX - size.width * 2) / GameTuning.worldChunkLength))
        ensureWorldGenerated(upTo: runStartX + size.width * 5)
        addIsland(centerX: runStartX, width: 108, topHeight: 13, isStartingPerch: true)

        pebble.position = CGPoint(x: physics.position.x, y: waterSurfaceY + physics.height)
        pebble.zRotation = 0
        currentCameraScale = 1
        cameraNode.setScale(currentCameraScale)
        cameraNode.position = CGPoint(x: runStartX + size.width * 0.18, y: size.height * 0.5)
        updateParallax()
        updateHUD()
        setInstruction("TOUCH • PULL BACK • RELEASE")
        showRegion(WaterRegion.at(worldX: runStartX))
        redrawWater(force: true)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        switch playState {
        case .ready:
            let location = touch.location(in: self)
            aimStart = location
            aimCurrent = location
            playState = .aiming
            setInstruction("PULL AWAY FROM THE THROW")
            showAimPreview()

        case .flying:
            applyMidairCorrection()

        case .results:
            let point = touch.location(in: resultPanel)
            if tryAgainButton.contains(point) {
                startNewRun()
            }

        case .aiming, .failing:
            break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard playState == .aiming, let touch = touches.first else { return }
        aimCurrent = touch.location(in: self)
        showAimPreview()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard playState == .aiming, let touch = touches.first else { return }
        aimCurrent = touch.location(in: self)
        commitThrow()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard playState == .aiming else { return }
        hideAimPreview()
        playState = .ready
        setInstruction("TOUCH • PULL BACK • RELEASE")
    }

    private func showAimPreview() {
        guard let start = aimStart, let current = aimCurrent else { return }
        let pull = cappedPull(from: start, to: current)
        let cappedTouch = CGPoint(x: start.x - pull.dx, y: start.y - pull.dy)
        let path = CGMutablePath()
        path.move(to: cappedTouch)
        path.addLine(to: start)
        aimLine.path = path
        aimLine.isHidden = false

        let power = min(1, hypot(pull.dx, pull.dy) / GameTuning.maximumPull)
        let fillPath = CGMutablePath()
        fillPath.move(to: CGPoint(x: -60, y: 0))
        fillPath.addLine(to: CGPoint(x: -60 + 120 * power, y: 0))
        powerFill.path = fillPath
        powerTrack.isHidden = false
        powerFill.isHidden = false

        let velocity = launchVelocity(for: pull)
        for (index, dot) in trajectoryDots.enumerated() {
            let time = CGFloat(index + 1) * 0.13
            let x = physics.position.x + velocity.dx * time
            let y = waterSurfaceY + physics.height + velocity.dy * time + 0.5 * GameTuning.gravity * time * time
            dot.position = CGPoint(x: x, y: y)
            dot.isHidden = false
        }
    }

    private func hideAimPreview() {
        aimLine.isHidden = true
        trajectoryDots.forEach { $0.isHidden = true }
        powerTrack.isHidden = true
        powerFill.isHidden = true
        aimStart = nil
        aimCurrent = nil
    }

    private func commitThrow() {
        guard let start = aimStart, let current = aimCurrent else { return }
        let pull = cappedPull(from: start, to: current)
        let distance = hypot(pull.dx, pull.dy)
        hideAimPreview()

        guard distance >= 14 else {
            playState = .ready
            setInstruction("A LITTLE MORE PULL")
            return
        }

        let velocity = launchVelocity(for: pull)
        physics.beginFlight(
            from: CGPoint(x: physics.position.x, y: max(physics.height, GameTuning.pebbleRadius + 4)),
            velocity: velocity
        )
        flightStartX = physics.position.x
        midairCorrectionsRemaining = WaterRegion.at(worldX: physics.position.x).allowedCorrections
        highMomentShown = false
        playState = .flying
        pebble.removeAllActions()
        pebble.setScale(1)
        setInstruction("TAP FOR A GENTLE LIFT")
        correctionLabel.text = correctionText
        correctionLabel.run(.sequence([.fadeAlpha(to: 0.65, duration: 0.15), .wait(forDuration: 2.2), .fadeOut(withDuration: 0.5)]))
        updateHUD()
    }

    private func cappedPull(from start: CGPoint, to current: CGPoint) -> CGVector {
        let raw = CGVector(dx: start.x - current.x, dy: start.y - current.y)
        let length = hypot(raw.dx, raw.dy)
        guard length > GameTuning.maximumPull else { return raw }
        let scale = GameTuning.maximumPull / max(length, 0.001)
        return CGVector(dx: raw.dx * scale, dy: raw.dy * scale)
    }

    private func launchVelocity(for pull: CGVector) -> CGVector {
        let length = hypot(pull.dx, pull.dy)
        let normalizedPower = min(1, max(0, length / GameTuning.maximumPull))
        let easedPower = normalizedPower * (2 - normalizedPower)
        let speed = GameTuning.minimumThrowSpeed
            + (GameTuning.maximumThrowSpeed - GameTuning.minimumThrowSpeed) * easedPower

        let rawAngle = atan2(pull.dy, max(pull.dx, 0.01))
        let angle = min(GameTuning.maximumLaunchAngle, max(GameTuning.minimumLaunchAngle, rawAngle))
        return CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
    }

    private func applyMidairCorrection() {
        guard midairCorrectionsRemaining > 0, physics.height > 18 else { return }
        midairCorrectionsRemaining -= 1
        physics.velocity.dy += GameTuning.midairLift
        physics.velocity.dx *= 1.012
        physics.remainingEnergy = min(1, physics.remainingEnergy + 0.012)
        correctionLabel.removeAllActions()
        correctionLabel.text = correctionText
        correctionLabel.alpha = 0.72
        correctionLabel.run(.sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.4)]))
        if midairCorrectionsRemaining == 0 { setInstruction("WATCH IT SKIP") }
        createLiftSpecks()
    }

    private var correctionText: String {
        guard midairCorrectionsRemaining > 0 else { return "LIFT SPENT" }
        return "\(midairCorrectionsRemaining) GENTLE LIFT\(midairCorrectionsRemaining == 1 ? "" : "S")"
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let deltaTime = min(GameTuning.maximumFrameDelta, max(0, currentTime - lastUpdateTime))
        lastUpdateTime = currentTime
        worldTime += deltaTime

        if playState == .flying {
            physicsAccumulator += deltaTime
            while physicsAccumulator >= GameTuning.fixedPhysicsStep && playState == .flying {
                updateFlight(deltaTime: CGFloat(GameTuning.fixedPhysicsStep))
                physicsAccumulator -= GameTuning.fixedPhysicsStep
            }
            if playState != .flying { physicsAccumulator = 0 }
        } else if playState == .results {
            physicsAccumulator = 0
            updateAutomaticRestart()
        } else {
            physicsAccumulator = 0
        }

        updateCamera(deltaTime: CGFloat(deltaTime))
        updateParallax()
        updatePalette()
        redrawWater(force: false)
        ensureWorldGenerated(upTo: cameraNode.position.x + size.width * 4)
    }

    private func updateFlight(deltaTime: CGFloat) {
        let previousHeight = physics.height
        physics.velocity.dy += physics.gravity * deltaTime
        physics.position.x += physics.velocity.dx * deltaTime
        physics.height += physics.velocity.dy * deltaTime
        physics.position.y = physics.height
        physics.horizontalTravel = physics.position.x - flightStartX
        physics.maximumHeight = max(physics.maximumHeight, physics.height)

        pebble.position = CGPoint(x: physics.position.x, y: waterSurfaceY + physics.height)
        pebble.zRotation -= (physics.velocity.dx / 58) * deltaTime
        pebbleGlow.alpha = min(0.34, 0.08 + CGFloat(physics.currentSkipChain) * 0.022)

        updateRegionProgress()
        updateHUD()

        if !highMomentShown, physics.height > size.height * 0.28 {
            highMomentShown = true
            createHighArcMoment()
        }

        if physics.velocity.dy < 0, let island = softLandingIsland(at: physics.position.x) {
            let landingHeight = island.topHeight + GameTuning.pebbleRadius * 0.55
            if physics.height <= landingHeight,
               physics.remainingEnergy < 0.59,
               physics.bounceCount >= 3,
               abs(physics.velocity.dy) < 350 {
                land(on: island)
                return
            }
        }

        let surfaceHeight = waveHeight(at: physics.position.x)
        let contactHeight = surfaceHeight + GameTuning.pebbleRadius * 0.36
        if physics.velocity.dy < 0, previousHeight > contactHeight, physics.height <= contactHeight {
            registerWaterContact(surfaceHeight: surfaceHeight)
        }
    }

    private func registerWaterContact(surfaceHeight: CGFloat) {
        physics.height = surfaceHeight + GameTuning.pebbleRadius * 0.38
        physics.position.y = physics.height
        physics.bounceCount += 1
        physics.currentSkipChain += 1
        runBestChain = max(runBestChain, physics.currentSkipChain)
        bestChain = max(bestChain, physics.currentSkipChain)
        UserDefaults.standard.set(bestChain, forKey: "pebbleSkip.bestChain")

        let blend = RegionBlend.at(worldX: physics.position.x)
        let region = blend.amount < 0.5 ? blend.current : blend.next
        let approachRatio = abs(physics.velocity.dy) / max(abs(physics.velocity.dx), 1)
        let shallowBonus = min(0.10, max(0, (0.62 - approachRatio) * 0.18))
        let variation = sin(CGFloat(physics.bounceCount) * 2.13 + physics.position.x * 0.011) * 0.014
        let retention = min(0.93, max(0.70, region.bounceRetention + shallowBonus + variation))
        physics.remainingEnergy *= retention
        physics.velocity.dx *= region.horizontalRetention

        createRipple(atX: physics.position.x, surfaceHeight: surfaceHeight, color: region.accentColor)
        pebble.run(.sequence([
            .scaleX(to: 1.22, y: 0.78, duration: 0.055),
            .scale(to: 1, duration: 0.11)
        ]))

        if physics.remainingEnergy < GameTuning.minimumEnergyToSkip || physics.velocity.dx < 105 {
            beginFailure(surfaceHeight: surfaceHeight)
            return
        }

        let downwardSpeed = abs(physics.velocity.dy)
        let baseLift = downwardSpeed * 0.38 + physics.velocity.dx * region.liftFromSpeed
        let energyScale = 0.55 + physics.remainingEnergy * 0.53
        let liftVariation = 1 + sin(physics.position.x * 0.019 + CGFloat(physics.bounceCount)) * 0.025
        physics.velocity.dy = min(310, max(92, baseLift * energyScale * liftVariation))

        maybePlaceRescueIsland()
        if physics.currentSkipChain == 5 || physics.currentSkipChain.isMultiple(of: 10) {
            createChainMilestone()
        }
        updateHUD()
    }

    private func softLandingIsland(at x: CGFloat) -> LandingIsland? {
        islands.first { abs(x - $0.centerX) <= $0.width * 0.48 }
    }

    private func land(on island: LandingIsland) {
        playState = .ready
        landingsThisRun += 1
        physics.velocity = .zero
        physics.position.x = min(island.centerX + island.width * 0.08, physics.position.x)
        physics.height = island.topHeight + GameTuning.pebbleRadius * 0.55
        physics.position.y = physics.height
        pebble.position = CGPoint(x: physics.position.x, y: waterSurfaceY + physics.height)
        pebble.run(.sequence([
            .scaleX(to: 1.08, y: 0.9, duration: 0.08),
            .scale(to: 1, duration: 0.18)
        ]))
        createLandingSpecks(at: pebble.position)
        setInstruction("SOFT LANDING • PULL TO THROW AGAIN")
        correctionLabel.removeAllActions()
        correctionLabel.alpha = 0
    }

    private func beginFailure(surfaceHeight: CGFloat) {
        guard playState == .flying else { return }
        playState = .failing
        setInstruction("A QUIET PLUNK…")
        correctionLabel.removeAllActions()
        correctionLabel.alpha = 0
        createRipple(atX: physics.position.x, surfaceHeight: surfaceHeight, color: cream)
        pebble.run(.group([
            .moveBy(x: 4, y: -18, duration: 0.45),
            .fadeAlpha(to: 0.18, duration: 0.45),
            .rotate(byAngle: -.pi * 0.8, duration: 0.45)
        ]))
        run(.sequence([
            .wait(forDuration: GameTuning.failurePause),
            .run { [weak self] in self?.showResults() }
        ]))
    }

    private func showResults() {
        let runDistance = max(0, Int((physics.position.x - runStartX) / GameTuning.pointsPerMeter))
        bestDistance = max(bestDistance, runDistance)
        UserDefaults.standard.set(bestDistance, forKey: "pebbleSkip.bestDistance")

        resultDistance.text = "\(runDistance) m"
        resultChain.text = "BEST CHAIN  \(runBestChain)"
        resultBest.text = "PERSONAL BEST  \(bestDistance) m  •  \(bestChain) skips"
        resultPanel.isHidden = false
        resultPanel.alpha = 0
        resultPanel.setScale(0.96)
        resultPanel.run(.group([
            .fadeIn(withDuration: 0.25),
            .scale(to: 1, duration: 0.32)
        ]))
        resultShownAt = worldTime
        playState = .results
        setInstruction("")
    }

    private func updateAutomaticRestart() {
        let elapsed = worldTime - resultShownAt
        let remaining = GameTuning.automaticRestartDelay - elapsed
        if remaining <= 0 {
            startNewRun()
            return
        }

        if remaining <= GameTuning.restartFlashDuration {
            let visible = 0.58 + 0.42 * (0.5 + 0.5 * sin(CGFloat(worldTime) * 7.5))
            tryAgainButton.alpha = visible
            tryAgainLabel.text = "TRY AGAIN  \(max(1, Int(ceil(remaining))))"
        } else {
            tryAgainButton.alpha = 1
            tryAgainLabel.text = "TRY AGAIN"
        }
    }

    private func updateCamera(deltaTime: CGFloat) {
        let velocityLead = playState == .flying ? min(size.width * 0.22, physics.velocity.dx * 0.10) : 0
        let desiredX = physics.position.x + size.width * 0.18 + velocityLead
        let heightFollow = max(0, physics.height - size.height * 0.46) * 0.22
        let desiredY = size.height * 0.5 + heightFollow
        let follow = 1 - pow(0.002, deltaTime)
        cameraNode.position.x += (desiredX - cameraNode.position.x) * follow
        cameraNode.position.y += (desiredY - cameraNode.position.y) * follow

        let desiredScale: CGFloat
        switch playState {
        case .aiming: desiredScale = 1.12
        case .flying: desiredScale = 0.97
        default: desiredScale = 1
        }
        currentCameraScale += (desiredScale - currentCameraScale) * min(1, deltaTime * 4.5)
        cameraNode.setScale(currentCameraScale)
    }

    private func updateParallax() {
        backgroundLayer.position.x = cameraNode.position.x * (1 - backgroundParallax)
        middleLayer.position.x = cameraNode.position.x * (1 - middleParallax)
    }

    private func updatePalette() {
        let blend = RegionBlend.at(worldX: physics.position.x)
        backgroundColor = .blended(from: blend.current.skyColor, to: blend.next.skyColor, amount: blend.amount)
        waterBody.fillColor = .blended(from: blend.current.waterColor, to: blend.next.waterColor, amount: blend.amount)
        waterCrest.strokeColor = cream.withAlphaComponent(0.16 + blend.amount * 0.05)
        celestialNode.fillColor = .blended(
            from: blend.current.accentColor.withAlphaComponent(0.42),
            to: blend.next.accentColor.withAlphaComponent(0.42),
            amount: blend.amount
        )
    }

    private func updateRegionProgress() {
        let region = WaterRegion.at(worldX: physics.position.x)
        if displayedRegion != region {
            displayedRegion = region
            showRegion(region)
        }

        if region.rawValue > unlockedRegionIndex {
            unlockedRegionIndex = region.rawValue
            UserDefaults.standard.set(unlockedRegionIndex, forKey: "pebbleSkip.unlockedRegion")
        }
    }

    private func showRegion(_ region: WaterRegion) {
        displayedRegion = region
        regionLabel.removeAllActions()
        regionSubtitleLabel.removeAllActions()
        regionLabel.text = region.name
        regionSubtitleLabel.text = region.subtitle
        regionLabel.alpha = 0
        regionSubtitleLabel.alpha = 0
        let reveal = SKAction.sequence([
            .fadeIn(withDuration: 0.45),
            .wait(forDuration: 1.6),
            .fadeOut(withDuration: 0.7)
        ])
        regionLabel.run(reveal)
        regionSubtitleLabel.run(.sequence([.wait(forDuration: 0.1), reveal]))
    }

    private func updateHUD() {
        let distance = max(0, Int((physics.position.x - runStartX) / GameTuning.pointsPerMeter))
        distanceLabel.text = "\(distance) m"
        let count = physics.currentSkipChain
        skipLabel.text = "\(count) SKIP\(count == 1 ? "" : "S")"
    }

    private func setInstruction(_ text: String) {
        instructionLabel.removeAllActions()
        instructionLabel.text = text
        instructionLabel.alpha = 0
        instructionLabel.run(.fadeAlpha(to: 0.82, duration: 0.18))
    }

    private func waveHeight(at x: CGFloat) -> CGFloat {
        let blend = RegionBlend.at(worldX: x)
        let current = rawWaveHeight(for: blend.current, at: x)
        let next = rawWaveHeight(for: blend.next, at: x)
        return current + (next - current) * blend.amount
    }

    private func rawWaveHeight(for region: WaterRegion, at x: CGFloat) -> CGFloat {
        switch region {
        case .pool:
            return sin(x * 0.025 + CGFloat(worldTime) * 0.72) * region.waveAmplitude
        case .lake:
            return sin(x * 0.017 + CGFloat(worldTime) * 0.78) * region.waveAmplitude
                + sin(x * 0.043 - CGFloat(worldTime) * 0.5) * 0.7
        case .ocean:
            return sin(x * 0.009 + CGFloat(worldTime) * 0.55) * region.waveAmplitude
                + sin(x * 0.021 - CGFloat(worldTime) * 0.32) * 1.8
        }
    }

    private func redrawWater(force: Bool) {
        guard force || worldTime - lastWaterDrawTime > 0.055 else { return }
        lastWaterDrawTime = worldTime
        let left = cameraNode.position.x - size.width * currentCameraScale * 0.8
        let right = cameraNode.position.x + size.width * currentCameraScale * 0.8
        let bottom = cameraNode.position.y - size.height * currentCameraScale
        let bodyPath = CGMutablePath()
        let crestPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: left, y: bottom))

        var x = left
        var isFirst = true
        while x <= right + 24 {
            let point = CGPoint(x: x, y: waterSurfaceY + waveHeight(at: x))
            bodyPath.addLine(to: point)
            if isFirst {
                crestPath.move(to: point)
                isFirst = false
            } else {
                crestPath.addLine(to: point)
            }
            x += 22
        }
        bodyPath.addLine(to: CGPoint(x: right + 24, y: bottom))
        bodyPath.closeSubpath()
        waterBody.path = bodyPath
        waterCrest.path = crestPath
    }

    private func ensureWorldGenerated(upTo targetX: CGFloat) {
        while CGFloat(nextChunkToGenerate) * GameTuning.worldChunkLength < targetX {
            createScenery(chunk: nextChunkToGenerate)
            nextChunkToGenerate += 1
        }
    }

    private func createScenery(chunk: Int) {
        let startX = CGFloat(chunk) * GameTuning.worldChunkLength
        let centerX = startX + GameTuning.worldChunkLength * 0.5
        let region = WaterRegion.at(worldX: max(0, centerX))
        let seed = randomUnit(chunk * 37 + region.rawValue * 101)

        switch region {
        case .pool:
            addPoolScenery(chunk: chunk, startX: startX, seed: seed)
        case .lake:
            addLakeScenery(chunk: chunk, startX: startX, seed: seed)
        case .ocean:
            addOceanScenery(chunk: chunk, startX: startX, seed: seed)
        }

        if seed > 0.78, abs(centerX - runStartX) > 190 {
            let width = 74 + randomUnit(chunk * 83) * 54
            addIsland(centerX: centerX + (seed - 0.5) * 180, width: width, topHeight: 8 + seed * 7)
        }
    }

    private func addPoolScenery(chunk: Int, startX: CGFloat, seed: CGFloat) {
        let region = WaterRegion.pool
        for index in 0..<3 {
            let bush = SKShapeNode(ellipseOf: CGSize(width: 130 + CGFloat(index) * 32, height: 74 + CGFloat(index) * 8))
            bush.fillColor = region.silhouetteColor.withAlphaComponent(0.22)
            bush.strokeColor = .clear
            bush.position = CGPoint(
                x: backgroundParallax * (startX + 90 + CGFloat(index) * 190),
                y: waterSurfaceY + 64 + CGFloat(index % 2) * 18
            )
            backgroundLayer.addChild(bush)
        }

        for index in 0..<4 {
            let x = middleParallax * (startX + 65 + CGFloat(index) * 130 + seed * 25)
            let stone = SKShapeNode(ellipseOf: CGSize(width: 42 + seed * 24, height: 25 + seed * 12))
            stone.fillColor = region.silhouetteColor.withAlphaComponent(0.72)
            stone.strokeColor = .clear
            stone.position = CGPoint(x: x, y: waterSurfaceY + 10)
            middleLayer.addChild(stone)
        }

        for index in 0..<5 {
            addReed(at: startX + 42 + CGFloat(index) * 112 + seed * 28, height: 28 + CGFloat(index % 3) * 9, color: region.silhouetteColor)
        }
    }

    private func addLakeScenery(chunk: Int, startX: CGFloat, seed: CGFloat) {
        let region = WaterRegion.lake
        let hillPath = CGMutablePath()
        hillPath.move(to: CGPoint(x: backgroundParallax * startX, y: waterSurfaceY - 2))
        hillPath.addQuadCurve(
            to: CGPoint(x: backgroundParallax * (startX + GameTuning.worldChunkLength), y: waterSurfaceY - 2),
            control: CGPoint(x: backgroundParallax * (startX + 280), y: waterSurfaceY + 145 + seed * 45)
        )
        hillPath.closeSubpath()
        let hill = SKShapeNode(path: hillPath)
        hill.fillColor = region.silhouetteColor.withAlphaComponent(0.34)
        hill.strokeColor = .clear
        backgroundLayer.addChild(hill)

        for index in 0..<4 {
            addPine(
                at: startX + 65 + CGFloat(index) * 145 + seed * 30,
                height: 58 + CGFloat(index % 2) * 22,
                color: region.silhouetteColor
            )
        }

        if chunk.isMultiple(of: 5) {
            addCabin(at: startX + 350, color: region.silhouetteColor)
        }
        addLilyPad(at: startX + 150 + seed * 240, color: region.accentColor)
        addLilyPad(at: startX + 405 - seed * 120, color: region.accentColor)
    }

    private func addOceanScenery(chunk: Int, startX: CGFloat, seed: CGFloat) {
        let region = WaterRegion.ocean
        let islandPath = CGMutablePath()
        let left = backgroundParallax * (startX + 40)
        let right = backgroundParallax * (startX + 520)
        islandPath.move(to: CGPoint(x: left, y: waterSurfaceY))
        islandPath.addCurve(
            to: CGPoint(x: right, y: waterSurfaceY),
            control1: CGPoint(x: left + 42, y: waterSurfaceY + 45 + seed * 45),
            control2: CGPoint(x: right - 58, y: waterSurfaceY + 92 - seed * 24)
        )
        islandPath.closeSubpath()
        let distantIsland = SKShapeNode(path: islandPath)
        distantIsland.fillColor = region.silhouetteColor.withAlphaComponent(0.48)
        distantIsland.strokeColor = .clear
        backgroundLayer.addChild(distantIsland)

        if chunk.isMultiple(of: 7) {
            addLighthouse(at: startX + 360, color: region.silhouetteColor, light: region.accentColor)
        }
        if seed > 0.34 {
            addBirds(at: startX + 190, height: waterSurfaceY + 150 + seed * 80)
        }
    }

    private func addReed(at worldX: CGFloat, height: CGFloat, color: SKColor) {
        let path = CGMutablePath()
        let localX = middleParallax * worldX
        path.move(to: CGPoint(x: localX, y: waterSurfaceY))
        path.addCurve(
            to: CGPoint(x: localX + 4, y: waterSurfaceY + height),
            control1: CGPoint(x: localX - 3, y: waterSurfaceY + height * 0.45),
            control2: CGPoint(x: localX + 5, y: waterSurfaceY + height * 0.75)
        )
        let reed = SKShapeNode(path: path)
        reed.strokeColor = color.withAlphaComponent(0.72)
        reed.lineWidth = 2
        middleLayer.addChild(reed)
    }

    private func addPine(at worldX: CGFloat, height: CGFloat, color: SKColor) {
        let x = middleParallax * worldX
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: waterSurfaceY + height))
        path.addLine(to: CGPoint(x: x - height * 0.28, y: waterSurfaceY))
        path.addLine(to: CGPoint(x: x + height * 0.28, y: waterSurfaceY))
        path.closeSubpath()
        let tree = SKShapeNode(path: path)
        tree.fillColor = color.withAlphaComponent(0.76)
        tree.strokeColor = .clear
        middleLayer.addChild(tree)
    }

    private func addCabin(at worldX: CGFloat, color: SKColor) {
        let x = middleParallax * worldX
        let cabin = SKShapeNode(rectOf: CGSize(width: 42, height: 24))
        cabin.fillColor = color.withAlphaComponent(0.82)
        cabin.strokeColor = .clear
        cabin.position = CGPoint(x: x, y: waterSurfaceY + 12)
        middleLayer.addChild(cabin)

        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: x - 25, y: waterSurfaceY + 22))
        roofPath.addLine(to: CGPoint(x: x, y: waterSurfaceY + 42))
        roofPath.addLine(to: CGPoint(x: x + 25, y: waterSurfaceY + 22))
        roofPath.closeSubpath()
        let roof = SKShapeNode(path: roofPath)
        roof.fillColor = color
        roof.strokeColor = .clear
        middleLayer.addChild(roof)
    }

    private func addLilyPad(at worldX: CGFloat, color: SKColor) {
        let pad = SKShapeNode(ellipseOf: CGSize(width: 34, height: 7))
        pad.fillColor = color.withAlphaComponent(0.52)
        pad.strokeColor = .clear
        pad.position = CGPoint(x: worldX, y: waterSurfaceY + waveHeight(at: worldX) + 1)
        foregroundLayer.addChild(pad)
    }

    private func addLighthouse(at worldX: CGFloat, color: SKColor, light: SKColor) {
        let x = middleParallax * worldX
        let towerPath = CGMutablePath()
        towerPath.move(to: CGPoint(x: x - 9, y: waterSurfaceY))
        towerPath.addLine(to: CGPoint(x: x - 5, y: waterSurfaceY + 68))
        towerPath.addLine(to: CGPoint(x: x + 5, y: waterSurfaceY + 68))
        towerPath.addLine(to: CGPoint(x: x + 10, y: waterSurfaceY))
        towerPath.closeSubpath()
        let tower = SKShapeNode(path: towerPath)
        tower.fillColor = color.withAlphaComponent(0.86)
        tower.strokeColor = .clear
        middleLayer.addChild(tower)

        let lamp = SKShapeNode(circleOfRadius: 7)
        lamp.fillColor = light.withAlphaComponent(0.7)
        lamp.strokeColor = .clear
        lamp.position = CGPoint(x: x, y: waterSurfaceY + 73)
        middleLayer.addChild(lamp)
    }

    private func addBirds(at worldX: CGFloat, height: CGFloat) {
        for index in 0..<3 {
            let x = middleParallax * worldX + CGFloat(index) * 22
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x - 8, y: height - CGFloat(index) * 6))
            path.addQuadCurve(to: CGPoint(x: x, y: height), control: CGPoint(x: x - 3, y: height + 5))
            path.addQuadCurve(to: CGPoint(x: x + 8, y: height - CGFloat(index) * 6), control: CGPoint(x: x + 3, y: height + 5))
            let bird = SKShapeNode(path: path)
            bird.strokeColor = cream.withAlphaComponent(0.46)
            bird.lineWidth = 1.4
            middleLayer.addChild(bird)
        }
    }

    private func addIsland(centerX: CGFloat, width: CGFloat, topHeight: CGFloat, isStartingPerch: Bool = false) {
        guard islands.allSatisfy({ abs($0.centerX - centerX) > ($0.width + width) * 0.42 }) else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width * 0.52, y: -8))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: topHeight),
            control: CGPoint(x: -width * 0.28, y: topHeight + 3)
        )
        path.addQuadCurve(
            to: CGPoint(x: width * 0.52, y: -8),
            control: CGPoint(x: width * 0.28, y: topHeight + 3)
        )
        path.addLine(to: CGPoint(x: width * 0.44, y: -18))
        path.addLine(to: CGPoint(x: -width * 0.46, y: -18))
        path.closeSubpath()

        let region = WaterRegion.at(worldX: centerX)
        let islandNode = SKShapeNode(path: path)
        islandNode.fillColor = region.silhouetteColor.withAlphaComponent(isStartingPerch ? 0.95 : 0.82)
        islandNode.strokeColor = region.accentColor.withAlphaComponent(0.25)
        islandNode.lineWidth = 1
        islandNode.position = CGPoint(x: centerX, y: waterSurfaceY)
        islandNode.zPosition = 3
        foregroundLayer.addChild(islandNode)
        islands.append(LandingIsland(centerX: centerX, width: width, topHeight: topHeight, node: islandNode))
    }

    private func maybePlaceRescueIsland() {
        guard physics.remainingEnergy > 0.25,
              physics.remainingEnergy < 0.52,
              physics.bounceCount >= 3 else { return }
        let seed = randomUnit(Int(physics.position.x / 11) + physics.bounceCount * 97 + landingsThisRun * 53)
        guard seed > 0.90 else { return }
        let flightTime = max(0.25, 2 * physics.velocity.dy / abs(GameTuning.gravity))
        let landingX = physics.position.x + physics.velocity.dx * flightTime
        guard islands.allSatisfy({ abs($0.centerX - landingX) > 145 }) else { return }
        addIsland(centerX: landingX, width: 112 + seed * 34, topHeight: 3.5 + seed * 2.5)
    }

    private func createRipple(atX x: CGFloat, surfaceHeight: CGFloat, color: SKColor) {
        for index in 0..<2 {
            let ripple = SKShapeNode(ellipseOf: CGSize(width: 18, height: 5))
            ripple.fillColor = .clear
            ripple.strokeColor = color.withAlphaComponent(0.58 - CGFloat(index) * 0.16)
            ripple.lineWidth = 1.2
            ripple.position = CGPoint(x: x, y: waterSurfaceY + surfaceHeight)
            ripple.zPosition = 2
            effectsLayer.addChild(ripple)
            ripple.run(.sequence([
                .wait(forDuration: Double(index) * 0.07),
                .group([
                    .scaleX(to: 4.2 + CGFloat(index), duration: 0.65),
                    .scaleY(to: 1.7, duration: 0.65),
                    .fadeOut(withDuration: 0.65)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func createLiftSpecks() {
        for index in 0..<3 {
            let speck = SKShapeNode(circleOfRadius: 1.5)
            speck.fillColor = cream.withAlphaComponent(0.6)
            speck.strokeColor = .clear
            speck.position = CGPoint(x: pebble.position.x - CGFloat(index) * 5, y: pebble.position.y - 3)
            speck.zPosition = 4
            effectsLayer.addChild(speck)
            speck.run(.sequence([
                .group([
                    .moveBy(x: -8 - CGFloat(index) * 3, y: -14, duration: 0.38),
                    .fadeOut(withDuration: 0.38)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func createLandingSpecks(at point: CGPoint) {
        for index in 0..<5 {
            let speck = SKShapeNode(circleOfRadius: 1.6)
            speck.fillColor = cream.withAlphaComponent(0.48)
            speck.strokeColor = .clear
            speck.position = point
            effectsLayer.addChild(speck)
            let direction = CGFloat(index - 2)
            speck.run(.sequence([
                .group([
                    .moveBy(x: direction * 7, y: 10 + abs(direction) * 2, duration: 0.32),
                    .fadeOut(withDuration: 0.32)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func createChainMilestone() {
        let count = physics.currentSkipChain >= 10 ? 8 : 5
        for index in 0..<count {
            let sparkle = SKShapeNode(circleOfRadius: 1.8)
            sparkle.fillColor = cream.withAlphaComponent(0.72)
            sparkle.strokeColor = .clear
            let angle = CGFloat(index) / CGFloat(count) * .pi * 2
            sparkle.position = pebble.position
            effectsLayer.addChild(sparkle)
            sparkle.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * 34, y: sin(angle) * 24 + 12, duration: 0.65),
                    .fadeOut(withDuration: 0.65)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func createHighArcMoment() {
        let birdY = pebble.position.y + 28
        for index in 0..<3 {
            let bird = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -7, y: 0))
            path.addQuadCurve(to: CGPoint(x: 0, y: 3), control: CGPoint(x: -3, y: 7))
            path.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 3, y: 7))
            bird.path = path
            bird.strokeColor = cream.withAlphaComponent(0.58)
            bird.lineWidth = 1.2
            bird.position = CGPoint(x: pebble.position.x + 58 + CGFloat(index) * 22, y: birdY + CGFloat(index % 2) * 11)
            bird.zPosition = 3
            effectsLayer.addChild(bird)
            bird.run(.sequence([
                .group([
                    .moveBy(x: 75, y: 8, duration: 2.2),
                    .fadeOut(withDuration: 2.2)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func randomUnit(_ seed: Int) -> CGFloat {
        let value = sin(CGFloat(seed) * 12.9898 + 78.233) * 43_758.5453
        return value - floor(value)
    }
}
