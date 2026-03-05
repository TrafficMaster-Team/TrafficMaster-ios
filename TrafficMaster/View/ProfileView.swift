//
//  ProfileView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var dailyCardsLimit: Int = 20
    @State private var reminderEnabled: Bool = true
    @State private var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @State private var showResetAlert = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            List {
                // СЕКЦИЯ А: Учетная запись (Header)
                Section {
                    Button(action: { showEditProfile = true }) {
                        HStack(spacing: 16) {
                            if let avatarData = profileManager.avatarData, let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundStyle(.gray, Color(UIColor.tertiarySystemFill))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profileManager.fullName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if !profileManager.username.isEmpty {
                                    Text("@\(profileManager.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Редактировать профиль")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // СЕКЦИЯ Б: Монетизация (TrafficMaster Premium)
                Section {
                    Button(action: {
                        // Действие для вызова Paywall
                    }) {
                        HStack(spacing: 16) {
                            SettingsIconView(icon: "star.fill", backgroundColor: .blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TrafficMaster Premium")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Безлимитные AI-объяснения")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // СЕКЦИЯ В: Настройки обучения
                Section(header: Text("Настройки обучения")) {
                    // Лимит новых карточек
                    HStack {
                        SettingsIconView(icon: "greetingcard.fill", backgroundColor: .orange)
                        Stepper("Новых карточек в день: \(dailyCardsLimit)", value: $dailyCardsLimit, in: 5...50, step: 5)
                    }
                    
                    // Ежедневное напоминание (Toggle)
                    HStack {
                        SettingsIconView(icon: "bell.badge.fill", backgroundColor: .red)
                        Toggle("Ежедневное напоминание", isOn: $reminderEnabled)
                    }
                    
                    // Время напоминания (показывается только если включено)
                    if reminderEnabled {
                        HStack {
                            // Пустая иконка для выравнивания
                            Color.clear.frame(width: 30, height: 30)
                            DatePicker("Время", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        }
                    }
                    
                    // Сброс прогресса
                    Button(action: {
                        showResetAlert = true
                    }) {
                        HStack {
                            SettingsIconView(icon: "trash.fill", backgroundColor: .gray)
                            Text("Сбросить весь прогресс")
                                .foregroundColor(.red)
                        }
                    }
                    .alert("Сброс прогресса", isPresented: $showResetAlert) {
                        Button("Отмена", role: .cancel) { }
                        Button("Сбросить", role: .destructive) {
                            // Логика удаления данных SwiftData
                        }
                    } message: {
                        Text("Вы уверены? Это удалит всю историю повторений и статистику. Это действие нельзя отменить.")
                    }
                }
                
                // СЕКЦИЯ Г: Приложение и поддержка
                Section(header: Text("Поддержка")) {
                    Button(action: {
                        // Действие для отзыва
                    }) {
                        HStack {
                            SettingsIconView(icon: "heart.fill", backgroundColor: .pink)
                            Text("Оценить приложение")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://t.me/traffic_master_team") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            SettingsIconView(icon: "envelope.fill", backgroundColor: .teal)
                            Text("Написать разработчикам")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button(action: {
                        // Открыть Safari/WebView
                    }) {
                        HStack {
                            SettingsIconView(icon: "hand.raised.fill", backgroundColor: .indigo)
                            Text("Политика конфиденциальности")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Версия приложения (Footer)
                Section {
                    HStack {
                        Spacer()
                        Text("Версия 1.0 (Build 1)")
                            .font(.footnote)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear) // Убираем фон ячейки
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Профиль")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
        }
    }
}

// MARK: - Вспомогательный UI для иконок настроек
struct SettingsIconView: View {
    let icon: String
    let backgroundColor: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(backgroundColor.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    ProfileView()
}
