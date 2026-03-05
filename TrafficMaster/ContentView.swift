//
//  ContentView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Question.nextReviewDate) private var questions: [Question] // Загружаем вопросы из базы
    
    @StateObject private var profileManager = ProfileManager.shared
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            if isShowingSplash || questions.isEmpty {
                SplashView()
                    .transition(.opacity)
            } else if !profileManager.isLoggedIn {
                LoginView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Запрашиваем разрешение на уведомления при первом запуске
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error = error {
                    print("Ошибка запроса уведомлений: \(error.localizedDescription)")
                }
            }
            
            // Искусственная задержка для сплеш-скрина, чтобы анимация успела проиграться
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isShowingSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Question.self, inMemory: true)
}
