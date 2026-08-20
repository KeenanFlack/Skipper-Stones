import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var scene: GameScene

    init() {
        let bounds = UIScreen.main.bounds
        _scene = State(initialValue: GameScene(size: bounds.size))
    }

    var body: some View {
        SpriteView(scene: scene, options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes])
            .ignoresSafeArea()
            .statusBarHidden(true)
    }
}
