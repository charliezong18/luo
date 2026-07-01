import SwiftUI
import SwiftData

@main
struct LuoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: CastRecord.self)
    }
}
