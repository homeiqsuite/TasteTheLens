import SwiftUI
import SwiftData

@main
struct Taste_The_LensApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: Recipe.self)
    }
}
