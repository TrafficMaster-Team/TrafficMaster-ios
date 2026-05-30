import SwiftUI
import Combine

@MainActor
final class AppNavigationState: ObservableObject {
    enum Tab: Int {
        case home = 0
        case statistics = 1
        case profile = 2
    }

    @Published var selectedTab: Tab = .home

    func select(_ tab: Tab) {
        selectedTab = tab
    }
}
