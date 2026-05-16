//
//  MainTabView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Главная")
                }
                .tag(0)
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Статистика")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Профиль")
                }
                .tag(2)
        }
        .tint(.blue)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .tabBar)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [Color.black.opacity(0.06), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 22)
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    MainTabView()
}
