//
//  StreakInsightsSheet.swift
//  TrafficMaster
//
//  Created by Codex on 03.06.26.
//

import Charts
import SwiftUI

struct StreakInsightsSheet: View {
    let streak: Int

    private let tracker = ProgressTracker.shared

    private var bestStreak: Int {
        tracker.calculateBestStreak()
    }

    private var totalCards: Int {
        tracker.totalStudiedCards()
    }

    private var activeDays: Int {
        tracker.totalActiveDays()
    }

    private var weeklyActivity: [DailyStudyActivity] {
        tracker.getDailyActivity(days: 7)
    }

    private var monthlyHeatmap: [Int] {
        tracker.getLast30Days()
    }

    private var averageDailyCards: Double {
        guard !weeklyActivity.isEmpty else { return 0 }
        let total = weeklyActivity.reduce(0) { $0 + $1.cards }
        return Double(total) / Double(weeklyActivity.count)
    }

    private var strongestDay: DailyStudyActivity? {
        weeklyActivity.max(by: { $0.cards < $1.cards })
    }

    private var achievements: [StreakAchievement] {
        [
            StreakAchievement(
                title: "Разогрев",
                subtitle: "1 день подряд",
                icon: "flame",
                tint: .orange,
                isUnlocked: streak >= 1
            ),
            StreakAchievement(
                title: "На ходу",
                subtitle: "3 дня подряд",
                icon: "bolt.fill",
                tint: .yellow,
                isUnlocked: streak >= 3
            ),
            StreakAchievement(
                title: "Ритм недели",
                subtitle: "7 дней подряд",
                icon: "calendar.badge.checkmark",
                tint: .blue,
                isUnlocked: streak >= 7
            ),
            StreakAchievement(
                title: "Железная дисциплина",
                subtitle: "14 дней подряд",
                icon: "shield.lefthalf.filled",
                tint: .green,
                isUnlocked: streak >= 14
            ),
            StreakAchievement(
                title: "Коллекционер",
                subtitle: "50 карточек решено",
                icon: "square.stack.3d.up.fill",
                tint: .purple,
                isUnlocked: totalCards >= 50
            ),
            StreakAchievement(
                title: "Марафонец",
                subtitle: "10 активных дней",
                icon: "figure.run",
                tint: .pink,
                isUnlocked: activeDays >= 10
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                streakHero
                metricsRow
                weeklyChartCard
                heatmapCard
                achievementsCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
    }

    private var streakHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(heroTitle)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    Text(
                        "Стрик растет, когда в течение дня ты решаешь хотя бы одну карточку. " +
                            "Даже короткая сессия держит темп."
                    )
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                }
                Spacer(minLength: 16)
                ZStack {
                    Circle()
                        .fill(.orange.opacity(0.2))
                        .frame(width: 68, height: 68)
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 12) {
                StreakChip(title: "Сейчас", value: "\(streak)")
                StreakChip(title: "Рекорд", value: "\(bestStreak)")
                StreakChip(title: "Карточек", value: "\(totalCards)")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            InsightStatCard(
                icon: "calendar",
                title: "Активных дней",
                value: "\(activeDays)",
                tint: .blue
            )
            InsightStatCard(
                icon: "chart.bar.fill",
                title: "Среднее за 7 дн.",
                value: averageDailyCards.formatted(.number.precision(.fractionLength(1))),
                tint: .green
            )
            InsightStatCard(
                icon: "sparkles",
                title: "Пик недели",
                value: "\(strongestDay?.cards ?? 0)",
                tint: .purple
            )
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Пульс активности")
                .font(.system(.title3, design: .rounded, weight: .bold))

            Chart(weeklyActivity) { item in
                BarMark(
                    x: .value("День", shortWeekday(for: item.date)),
                    y: .value("Карточки", item.cards)
                )
                .foregroundStyle(
                    item.cards == strongestDay?.cards ? Color.orange : Color.orange.opacity(0.35)
                )
                .cornerRadius(8)

                if !weeklyActivity.isEmpty && item.cards > 0 {
                    PointMark(
                        x: .value("День", shortWeekday(for: item.date)),
                        y: .value("Карточки", item.cards)
                    )
                    .foregroundStyle(.orange)
                    .symbolSize(45)
                }

                RuleMark(y: .value("Среднее", averageDailyCards))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 180)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .chartXAxisLabel("Последние 7 дней")
            .accessibilityLabel("График активности за последние 7 дней")

            Text(weeklyInsightText)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("След за 30 дней")
                .font(.system(.title3, design: .rounded, weight: .bold))

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 10),
                spacing: 6
            ) {
                ForEach(Array(monthlyHeatmap.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(heatmapColor(for: level))
                        .frame(height: 18)
                }
            }

            HStack(spacing: 8) {
                Text("Редко")
                    .foregroundColor(.secondary)
                ForEach(0 ... 5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(heatmapColor(for: level))
                        .frame(width: 16, height: 10)
                }
                Text("Часто")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ачивки")
                .font(.system(.title3, design: .rounded, weight: .bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(achievements) { achievement in
                    AchievementTile(achievement: achievement)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var heroTitle: String {
        switch streak {
        case 0:
            return "Запусти первый огонь"
        case 1 ..< 3:
            return "Стрик уже жив"
        case 3 ..< 7:
            return "Неплохой ритм"
        case 7 ..< 14:
            return "Неделя без срывов"
        default:
            return "Это уже серьезная серия"
        }
    }

    private var weeklyInsightText: String {
        guard let strongestDay else {
            return "Когда появятся первые решенные карточки, здесь будет видно твой ритм недели."
        }

        return "Лучший день недели: \(fullDayLabel(for: strongestDay.date)) с " +
            "\(strongestDay.cards) карточками. Средний темп помогает не терять стрик " +
            "даже в загруженные дни."
    }

    private func shortWeekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: date).capitalized
    }

    private func fullDayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func heatmapColor(for level: Int) -> Color {
        if level == 0 {
            return Color.gray.opacity(0.12)
        }

        let opacity = 0.24 + (Double(level) * 0.12)
        return Color.orange.opacity(min(opacity, 0.95))
    }
}

struct StreakChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.primary.opacity(0.8))
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct InsightStatCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct StreakAchievement: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isUnlocked: Bool
}

struct AchievementTile: View {
    let achievement: StreakAchievement

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(achievement.isUnlocked ? achievement.tint : .secondary)
                Spacer()
                Image(systemName: achievement.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(
                        achievement.isUnlocked ? achievement.tint : .secondary.opacity(0.7)
                    )
            }

            Text(achievement.title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
            Text(achievement.subtitle)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    achievement.isUnlocked ?
                        achievement.tint.opacity(0.15) :
                        Color(UIColor.tertiarySystemFill)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    achievement.isUnlocked ? achievement.tint.opacity(0.5) : .clear,
                    lineWidth: 1
                )
        )
    }
}

#Preview("Streak Sheet") {
    StreakInsightsSheet(streak: 8)
}
