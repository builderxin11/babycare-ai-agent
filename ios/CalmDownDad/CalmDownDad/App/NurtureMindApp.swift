import SwiftUI

@main
struct NurtureMindApp: App {
    @StateObject private var amplifyService = AmplifyService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(amplifyService)
                .task {
                    await amplifyService.configure()
                }
        }
    }
}
