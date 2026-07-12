import SwiftUI

// The product name is a proper noun and must remain unchanged.
// swiftlint:disable:next inclusive_language
struct TrafficMasterCommands: Commands {
    @ObservedObject var navigationState: AppNavigationState

    var body: some Commands {
        CommandMenu("Навигация") {
            Button("Главная") {
                navigationState.select(.home)
            }
            .keyboardShortcut("1")

            Button("Статистика") {
                navigationState.select(.statistics)
            }
            .keyboardShortcut("2")

            Button("Профиль") {
                navigationState.select(.profile)
            }
            .keyboardShortcut("3")
        }
    }
}
