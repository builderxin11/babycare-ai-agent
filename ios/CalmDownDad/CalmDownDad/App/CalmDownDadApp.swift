import SwiftUI

@main
struct CalmDownDadApp: App {
    @StateObject private var amplifyService = AmplifyService.shared
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(amplifyService)
                .environmentObject(languageManager)
                .task {
                    await amplifyService.configure()
                }
        }
    }
}
