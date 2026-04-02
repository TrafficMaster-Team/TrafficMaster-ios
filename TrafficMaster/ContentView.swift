//
//  ContentView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var viewModel = QuestionViewModel()
    @State private var isLoggedIn = false
    @State private var showLogin = false
    @State private var errorMessage: String? = nil
    
    private let profileManager = ProfileManager.shared

    var body: some View {
        ZStack {
            if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text("Ошибка загрузки данных")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Повторить") {
                        errorMessage = nil
                        viewModel.loadQuestions()
                        if viewModel.allQuestions.isEmpty {
                            errorMessage = "База данных пуста (0 вопросов)."
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.allQuestions.isEmpty {
                // Ждем загрузки базы (если это первый запуск)
                ProgressView("Загрузка данных...")
                    .onAppear {
                        // Проверяем статус входа
                        isLoggedIn = profileManager.isLoggedIn
                        showLogin = !isLoggedIn
                        
                        // Пытаемся загрузить вопросы
                        viewModel.loadQuestions()
                        
                        // Если после загрузки все равно пусто, подождем немного и проверим еще раз
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            if viewModel.allQuestions.isEmpty {
                                self.errorMessage = "База данных пуста или импорт завис. Перезапустите приложение."
                            }
                        }
                    }
            } else if showLogin {
                LoginView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Запрашиваем разрешение на уведомления при первом запуске
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
                if let error = error {
                    print("Ошибка запроса уведомлений: \(error.localizedDescription)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DatabaseImportCompleted"))) { _ in
            // Как только фоновый импорт завершен, просим viewModel загрузить вопросы еще раз
            viewModel.loadQuestions()
            if viewModel.allQuestions.isEmpty {
                errorMessage = "Импорт завершен, но вопросов в базе 0."
            } else {
                errorMessage = nil
            }
        }
        .onChange(of: profileManager.isLoggedIn) { _, newValue in
            withAnimation {
                isLoggedIn = newValue
                showLogin = !newValue
            }
        }
    }
}

#Preview {
    ContentView()
}
