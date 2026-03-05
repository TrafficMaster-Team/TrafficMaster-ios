//
//  StatisticsView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var animateCharts = false
    
    // Моковые данные для состава коллекции
    let collectionData: [CardStatus] = [
        CardStatus(type: "Новые", count: 420, color: .blue),
        CardStatus(type: "Изучаемые", count: 150, color: .orange),
        CardStatus(type: "Закрепленные", count: 330, color: .green)
    ]
    
    // Моковые данные для Heatmap (последние 30 дней)
    let heatmapData: [Int] = (0..<30).map { _ in Int.random(in: 0...5) }
    
    // Моковые данные для слабых тем
    let weakTopics: [WeakTopic] = [
        WeakTopic(name: "Перекрестки", errorRate: 45, icon: "arrow.triangle.merge"),
        WeakTopic(name: "Сигналы регулировщика", errorRate: 38, icon: "figure.arms.open"),
        WeakTopic(name: "Остановка и стоянка", errorRate: 25, icon: "parkingsign.circle")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Блок А: Summary (Сводка)
                        HStack(spacing: 16) {
                            SummaryCard(icon: "flame.fill", title: "Стрик", value: "14 дней", color: .orange)
                            SummaryCard(icon: "brain.head.profile", title: "Готовность", value: "68%", color: .blue)
                            SummaryCard(icon: "clock.badge.checkmark", title: "AI сэкономил", value: "3 ч", color: .green)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Прогноз на завтра
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.blue)
                                Text("Прогноз на завтра: 45 карточек")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            .foregroundColor(.primary)
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(Color.blue)
                                        .frame(width: animateCharts ? geometry.size.width * 0.45 : 0, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 20)
                        
                        // Блок Б: Состав коллекции (SectorMark / Круговая диаграмма)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Состав коллекции")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            
                            HStack(spacing: 24) {
                                // График
                                Chart(collectionData) { data in
                                    SectorMark(
                                        angle: .value("Количество", animateCharts ? data.count : 0),
                                        innerRadius: .ratio(0.65),
                                        angularInset: 2.0
                                    )
                                    .foregroundStyle(data.color)
                                    .cornerRadius(6)
                                }
                                .frame(width: 140, height: 140)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animateCharts)
                                
                                // Легенда
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(collectionData) { data in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(data.color)
                                                .frame(width: 10, height: 10)
                                            VStack(alignment: .leading) {
                                                Text(data.type)
                                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                Text("\(data.count)")
                                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 20)
                        
                        // Календарь активности (Heatmap)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Активность (последние 30 дней)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                            
                            // Сетка 7 строк х ~4 столбца (упрощенный вид)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 10), spacing: 6) {
                                ForEach(0..<30, id: \.self) { index in
                                    let activityLevel = heatmapData[index]
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(activityColor(for: activityLevel))
                                        .aspectRatio(1, contentMode: .fit)
                                        .scaleEffect(animateCharts ? 1 : 0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.01), value: animateCharts)
                                }
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 20)
                        
                        // Блок В: Топ слабых тем
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Топ слабых тем")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                            }
                            
                            VStack(spacing: 16) {
                                ForEach(weakTopics) { topic in
                                    HStack(spacing: 16) {
                                        Image(systemName: topic.icon)
                                            .font(.title3)
                                            .foregroundColor(.red)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(topic.name)
                                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                Spacer()
                                                Text("\(topic.errorRate)% ошибок")
                                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                                    .foregroundColor(.red)
                                            }
                                            
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    Capsule()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(height: 6)
                                                    
                                                    Capsule()
                                                        .fill(Color.red)
                                                        .frame(width: animateCharts ? geometry.size.width * CGFloat(topic.errorRate) / 100 : 0, height: 6)
                                                }
                                            }
                                            .frame(height: 6)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        
                    }
                }
            }
            .navigationTitle("Прогресс")
            .onAppear {
                // Запускаем анимации при открытии экрана
                withAnimation(.easeOut(duration: 0.8)) {
                    animateCharts = true
                }
            }
            .onDisappear {
                // Сбрасываем, чтобы при повторном открытии анимация играла снова
                animateCharts = false
            }
        }
    }
    
    // Вспомогательная функция для Heatmap
    private func activityColor(for level: Int) -> Color {
        if level == 0 {
            return Color.gray.opacity(0.15)
        }
        // Чем выше уровень, тем насыщеннее зеленый (от 0.3 до 1.0)
        let intensity = 0.2 + (Double(level) * 0.16)
        return Color.green.opacity(min(intensity, 1.0))
    }
}

// MARK: - Models & Subviews

struct CardStatus: Identifiable {
    let id = UUID()
    let type: String
    let count: Int
    let color: Color
}

struct WeakTopic: Identifiable {
    let id = UUID()
    let name: String
    let errorRate: Int
    let icon: String
}

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    StatisticsView()
}
