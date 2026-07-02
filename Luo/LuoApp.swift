import SwiftUI
import SwiftData
import CoreText

@main
struct LuoApp: App {
    init() { Theme.registerBundledFonts() }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: CastRecord.self)
    }
}
