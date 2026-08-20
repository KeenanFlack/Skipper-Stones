import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var scene = GameScene(size: UIScreen.main.bounds.size)

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
            VStack {
                HStack {
                    Text("SKIPPER STONES")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                    Spacer()
                    Text("BEST  (scene.bestScore)")
                        .font(.caption.monospaced().weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 24)
                .padding(.top, 16)
                Spacer()
                Text(scene.instruction)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 28)
            }
            .allowsHitTesting(false)
        }
        .statusBarHidden(true)
    }
}
