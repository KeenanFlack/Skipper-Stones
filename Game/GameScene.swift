import SpriteKit

final class GameScene: SKScene {
    private let water = SKColor(red: 0.04, green: 0.28, blue: 0.38, alpha: 1)
    private var stone: SKShapeNode!
    private var dragStart: CGPoint?
    private var bounceCount = 0
    private(set) var bestScore = UserDefaults.standard.integer(forKey: "bestScore")
    private(set) var instruction = "DRAG THE STONE, THEN RELEASE"

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = water
        addWaterLines()
        resetStone()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        stone?.position = CGPoint(x: size.width * 0.2, y: size.height * 0.25)
    }

    private func addWaterLines() {
        for index in 0..<12 {
            let line = SKShapeNode(rectOf: CGSize(width: size.width * 0.7, height: 1))
            line.position = CGPoint(x: size.width * 0.6, y: size.height * (0.12 + CGFloat(index) * 0.065))
            line.strokeColor = .white.withAlphaComponent(0.08)
            line.zPosition = -1
            addChild(line)
        }
    }

    private func resetStone() {
        stone?.removeFromParent()
        bounceCount = 0
        stone = SKShapeNode(circleOfRadius: 20)
        stone.fillColor = SKColor(red: 0.78, green: 0.71, blue: 0.55, alpha: 1)
        stone.strokeColor = .white.withAlphaComponent(0.25)
        stone.position = CGPoint(x: size.width * 0.2, y: size.height * 0.25)
        stone.name = "stone"
        addChild(stone)
        instruction = "DRAG THE STONE, THEN RELEASE"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, stone.contains(touch.location(in: self)) else { return }
        dragStart = touch.location(in: self)
        instruction = "AIM OVER THE WATER"
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, dragStart != nil else { return }
        stone.position = touch.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let start = dragStart, let touch = touches.first else { return }
        let end = touch.location(in: self)
        let vector = CGVector(dx: (start.x - end.x) * 2.5, dy: (start.y - end.y) * 2.5)
        dragStart = nil
        instruction = "WATCH IT SKIP"
        throwStone(with: vector)
    }

    private func throwStone(with velocity: CGVector) {
        stone.removeAllActions()
        let destination = CGPoint(x: max(size.width * 0.55, stone.position.x + velocity.dx), y: max(size.height * 0.18, stone.position.y + velocity.dy * 0.35))
        let duration = max(0.45, min(1.4, Double(abs(velocity.dx) / 650)))
        let arc = SKAction.group([SKAction.move(to: destination, duration: duration), SKAction.rotate(byAngle: -.pi * 3, duration: duration)])
        stone.run(arc) { [weak self] in self?.registerBounce() }
    }

    private func registerBounce() {
        bounceCount += 1
        bestScore = max(bestScore, bounceCount)
        UserDefaults.standard.set(bestScore, forKey: "bestScore")
        instruction = "\(bounceCount) SKIP\(bounceCount == 1 ? "" : "S") — GO AGAIN"
        let pulse = SKAction.sequence([SKAction.scale(to: 1.35, duration: 0.08), SKAction.scale(to: 1, duration: 0.14)])
        stone.run(pulse) { [weak self] in self?.resetStone() }
    }
}
