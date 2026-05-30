//
//  StatisticsView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import Charts
import SwiftUI

struct StatisticsView: View {
    @State private var allQuestions: [Question] = []
    @State private var animateCharts = false
    @State private var isLoading = true
    
    // Динамические вычисления для статистики
    var collectionData: [CardStatus] {
        let newCards = allQuestions.filter { $0.repetitions == 0 }.count
        let learningCards = allQuestions.filter { $0.repetitions > 0 && $0.repetitions < 10 }.count
        let masteredCards = allQuestions.filter { $0.repetitions >= 10 }.count
        
        return [
            CardStatus(type: "Новые", count: newCards, color: .blue),
            CardStatus(type: "Изучаемые", count: learningCards, color: .orange),
            CardStatus(type: "Закрепленные", count: masteredCards, color: .green)
        ]
    }
    
    var readinessPercentage: Int {
        if allQuestions.isEmpty { return 0 }
        let totalStability = allQuestions.reduce(0.0) { $0 + $1.stability }
        let averageStability = totalStability / Double(allQuestions.count)
        // Normalization for readiness
        let percentage = (averageStability / 50.0) * 100 
        return min(Int(percentage), 100)
    }
    
    var forecastForTomorrow: Int {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        return allQuestions.filter { 
            $0.repetitions > 0 && calendar.isDate($0.nextReviewDate, inSameDayAs: tomorrow)
        }.count
    }
    
    var heatmapData: [Int] {
        return ProgressTracker.shared.getLast30Days()
    }
    
    var weakTopics: [WeakTopic] {
        let sectionsDict = Dictionary(grouping: allQuestions, by: { $0.chapterTitle ?? "Неизвестно" })
        
        var topicStats: [WeakTopic] = []
        for (chapter, questions) in sectionsDict {
            let answeredQuestions = questions.filter { $0.repetitions > 0 }
            if answeredQuestions.isEmpty { continue }
            
            // SM-2 ease based
            let avgDifficulty = answeredQuestions.reduce(0.0) { $0 + $1.difficulty } / Double(answeredQuestions.count)
            let errorRate = Int((avgDifficulty / 10.0) * 100)
            
            if errorRate > 30 { 
                topicStats.append(WeakTopic(name: chapter, errorRate: errorRate, icon: "exclamationmark.triangle"))
            }
        }
        
        return Array(topicStats.sorted(by: { $0.errorRate > $1.errorRate }).prefix(3))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Анализ данных...")
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // Блок А: Summary (Сводка)
                            HStack(spacing: 16) {
                                let streak = ProgressTracker.shared.calculateStreak()
                                let savedHours = ProgressTracker.shared.calculateSavedTimeHours()
                                
                                SummaryCard(icon: "flame.fill", title: "Стрик", value: "\(streak) дн.", color: .orange)
                                SummaryCard(icon: "brain.head.profile", title: "Готовность", value: "\(readinessPercentage)%", color: .blue)
                                SummaryCard(icon: "clock.badge.checkmark", title: "Сэкономлено", value: "\(savedHours) ч", color: .green)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            
                            // Прогноз на завтра
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.blue)
                                    Text("Прогноз на завтра: \(forecastForTomorrow) карточек")
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
                            
                            // Блок Б: Состав коллекции
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Состав коллекции")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                
                                HStack(spacing: 24) {
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
                                
                                if weakTopics.isEmpty {
                                    Text("У вас пока нет слабых тем. Так держать!")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 10)
                                } else {
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
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Прогресс")
            .onAppear {
                loadData()
            }
            .onDisappear {
                animateCharts = false
            }
        }
    }
    
    private func loadData() {
        do {
            allQuestions = try DatabaseService.shared.fetchAllQuestions()
            isLoading = false
            withAnimation(.easeOut(duration: 0.8)) {
                animateCharts = true
            }
        } catch {
            print("❌ Statistics: Failed to load data: \(error)")
            isLoading = false
        }
    }
    
    private func activityColor(for level: Int) -> Color {
        if level == 0 {
            return Color.gray.opacity(0.15)
        }
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
