//
//  AppStorePromoteSheet.swift
//  TrafficMasterClip
//
//  Created by Влад on 12/10/26.
//

import SwiftUI
import StoreKit

struct AppStorePromoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon & Title
                    VStack(spacing: 12) {
                        Image(systemName: "car.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(.accentColor)
                            .shadow(color: .accentColor.opacity(0.3), radius: 10, y: 5)
                        
                        VStack(spacing: 4) {
                            Text("TrafficMaster")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            Text("Полная версия для iOS")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 16)
                    
                    // Value Proposition List
                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(
                            icon: "books.vertical.fill",
                            color: .blue,
                            title: "Все 152 темы и 2500+ билетов",
                            subtitle: "Полная актуальная база ПДД с официальными изменениями"
                        )
                        
                        featureRow(
                            icon: "brain.head.profile.fill",
                            color: .purple,
                            title: "Персональный SM-2 трекинг",
                            subtitle: "Умное распределение повторений исключает забывание материала"
                        )
                        
                        featureRow(
                            icon: "bubble.left.and.sparkles.fill",
                            color: .green,
                            title: "Встроенный AI-Тьютор",
                            subtitle: "Объясняет логику любого спорного перекрестка в один тап"
                        )
                        
                        featureRow(
                            icon: "checkmark.shield.fill",
                            color: .orange,
                            title: "Симулятор реального экзамена ГАИ",
                            subtitle: "Таймер, лимит ошибок и строгие алгоритмы проверки"
                        )
                        
                        featureRow(
                            icon: "wifi.slash",
                            color: .teal,
                            title: "100% Offline-режим",
                            subtitle: "Учись в метро, на полигоне или за городом без интернета"
                        )
                    }
                    .padding(18)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(20)
                    
                    // Download Call-to-action
                    VStack(spacing: 12) {
                        Button {
                            // Link to App Store product page
                            if let url = URL(string: "https://apps.apple.com/app/id6470000000") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.app.fill")
                                Text("Установить полную версию")
                            }
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        
                        Text("Бесплатный пробный период 7 дней • Без рекламы")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
            }
        }
    }
    
    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
    }
}
