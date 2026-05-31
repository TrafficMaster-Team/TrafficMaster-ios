import SwiftUI

@main
struct TrafficMasterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    _ = DatabaseService.shared
                    try? DatabaseService.shared.importBundledQuestionsIfNeeded()
                }
        }
    }
}
