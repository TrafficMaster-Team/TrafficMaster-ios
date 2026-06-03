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
                    Button(action: {
                        showEditProfile = true
                    }, label: {
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
                    })
                }
                
                // СЕКЦИЯ Б: Монетизация (TrafficMaster Ученик)
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            SettingsIconView(icon: "graduationcap.fill", backgroundColor: .blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("TrafficMaster Ученик")
                                    .font(.system(.headline, weight: .bold))
                                    .foregroundStyle(.primary)

                                Text(profileManager.hasStudentSubscription ? "Подписка активна" : "Премиум-возможности для подготовки")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            SubscriptionStatusPill(isActive: profileManager.hasStudentSubscription)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("39 BYN")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text("в месяц")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(
                                "Справедливая цена: баланс между экономией времени на подготовку, " +
                                "снижением риска не сдать экзамен и стоимостью конкурентов."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            SubscriptionBenefitRow(icon: "sparkles", text: "Безлимитные AI-объяснения без дневного лимита")
                            SubscriptionBenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Расширенная статистика вероятности сдачи")
                            SubscriptionBenefitRow(
                                icon: "rectangle.stack.fill",
                                text: "Умные подборки карточек и доступ к симулятору экзамена"
                            )
                        }
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                } footer: {
                    Text("Базовая работа с карточками интервального повторения остается бесплатной.")
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
                    }, label: {
                        HStack {
                            SettingsIconView(icon: "trash.fill", backgroundColor: .gray)
                            Text("Сбросить весь прогресс")
                                .foregroundColor(.red)
                        }
                    })
                    .alert("Сброс прогресса", isPresented: $showResetAlert) {
                        Button("Отмена", role: .cancel) { }
                        Button("Сбросить", role: .destructive) {
                            // Логика удаления данных SwiftData
                        }
                    } message: {
                        let msg = "Вы уверены? Это удалит всю историю повторений и статистику. Это действие нельзя отменить."
                        Text(msg)
                    }
                }
                
                // СЕКЦИЯ Г: Приложение и поддержка
                Section(header: Text("Поддержка")) {
                    Button(action: {
                        // Действие для отзыва
                    }, label: {
                        HStack {
                            SettingsIconView(icon: "heart.fill", backgroundColor: .pink)
                            Text("Оценить приложение")
                                .foregroundColor(.primary)
                        }
                    })
                    
                    Button(action: {
                        if let url = URL(string: "https://t.me/traffic_master_team") {
                            UIApplication.shared.open(url)
                        }
                    }, label: {
                        HStack {
                            SettingsIconView(icon: "envelope.fill", backgroundColor: .teal)
                            Text("Написать разработчикам")
                                .foregroundColor(.primary)
                        }
                    })
                    
                    Button(action: {
                        // Открыть Safari/WebView
                    }, label: {
                        HStack {
                            SettingsIconView(icon: "hand.raised.fill", backgroundColor: .indigo)
                            Text("Политика конфиденциальности")
                                .foregroundColor(.primary)
                        }
                    })
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

// MARK: - Вспомогательный UI подписки
struct SubscriptionStatusPill: View {
    let isActive: Bool

    var body: some View {
        Text(isActive ? "Активна" : "Доступна")
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(isActive ? .green : .blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isActive ? Color.green : Color.blue).opacity(0.12), in: Capsule())
    }
}

struct SubscriptionBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 18, height: 18)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
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
