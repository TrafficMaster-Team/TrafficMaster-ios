//
//  MainTabView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var navigationState: AppNavigationState

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Главная")
                }
                .tag(AppNavigationState.Tab.home)

            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Статистика")
                }
                .tag(AppNavigationState.Tab.statistics)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Профиль")
                }
                .tag(AppNavigationState.Tab.profile)
        }
        .tint(.blue)
#if os(iOS)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
#endif
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppNavigationState())
}
