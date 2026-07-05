import SwiftUI
import SwiftData
import CoreText

@main
struct LuoApp: App {
    init() {
        Theme.registerBundledFonts()
        // Pre-warm the procedural coin PBR maps (one-time, seconds of per-pixel
        // work) so entering a Ritual doesn't block on texture generation.
        Task.detached(priority: .userInitiated) {
            _ = CoinTexture.inscribedFace()
            _ = CoinTexture.blankFace()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: CastRecord.self)
    }
}
