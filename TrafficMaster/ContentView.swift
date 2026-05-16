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
    @State private var hasLoadedQuestions = false

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
                        Task { @MainActor in
                            viewModel.loadQuestions()
                            if viewModel.allQuestions.isEmpty {
                                errorMessage = "База данных пуста (0 вопросов)."
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.allQuestions.isEmpty && !hasLoadedQuestions {
                // Ждем загрузки базы (если это первый запуск)
                ProgressView("Загрузка данных...")
                    .onAppear {
                        guard !hasLoadedQuestions else { return }
                        
                        // Проверяем статус входа
                        isLoggedIn = profileManager.isLoggedIn
                        showLogin = !isLoggedIn

                        // Пытаемся загрузить вопросы
                        loadInitialData()
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
            Task { @MainActor in
                viewModel.loadQuestions()
                if viewModel.allQuestions.isEmpty {
                    errorMessage = "Импорт завершен, но вопросов в базе 0."
                } else {
                    errorMessage = nil
                    hasLoadedQuestions = true
                }
            }
        }
        .onChange(of: profileManager.isLoggedIn) { _, newValue in
            withAnimation {
                isLoggedIn = newValue
                showLogin = !newValue
            }
        }
    }
    
    private func loadInitialData() {
        Task { @MainActor in
            // Сначала проверяем, есть ли уже данные
            viewModel.loadQuestions()
            
            if !viewModel.allQuestions.isEmpty {
                hasLoadedQuestions = true
                return
            }
            
            // Если данных нет, ждем до 10 секунд (импорт в фоне)
            var waited: TimeInterval = 0
            let checkInterval: TimeInterval = 0.5
            
            while waited < 10.0 && viewModel.allQuestions.isEmpty {
                try? await Task.sleep(for: .seconds(checkInterval))
                waited += checkInterval
                viewModel.loadQuestions()
            }
            
            // Если после ожидания всё ещё пусто — ошибка
            if viewModel.allQuestions.isEmpty {
                errorMessage = "База данных пуста или импорт завис. Перезапустите приложение."
            } else {
                hasLoadedQuestions = true
            }
        }
    }
}

#Preview {
    ContentView()
}
