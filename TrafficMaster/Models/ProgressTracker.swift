//
//  ProgressTracker.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import Foundation

struct DailyStudyActivity: Identifiable, Hashable {
    let date: Date
    let cards: Int

    var id: Date { date }
}

class ProgressTracker {
    static let shared = ProgressTracker()
    private let defaults = UserDefaults.standard
    private let historyKey = "study_history"

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    func getHistory() -> [String: Int] {
        defaults.dictionary(forKey: historyKey) as? [String: Int] ?? [:]
    }

    // Вызывается каждый раз, когда карточка успешно пройдена
    func logCardStudied() {
        var history = getHistory()
        let today = dateFormatter.string(from: Date())
        history[today, default: 0] += 1
        defaults.set(history, forKey: historyKey)
    }

    // Рассчитывает текущий стрик в днях
    func calculateStreak() -> Int {
        let history = getHistory()
        var streak = 0
        let date = Date()
        let calendar = Calendar.current

        let todayStr = dateFormatter.string(from: date)
        let studiedToday = (history[todayStr] ?? 0) > 0

        if studiedToday {
            streak += 1
        }

        var checkDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        while true {
            let dateStr = dateFormatter.string(from: checkDate)
            if let count = history[dateStr], count > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        return streak
    }

    func calculateBestStreak() -> Int {
        let calendar = Calendar.current
        let activeDates = getHistory()
            .filter { $0.value > 0 }
            .keys
            .compactMap { dateFormatter.date(from: $0) }
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        guard var previousDate = activeDates.first else {
            return 0
        }

        var bestStreak = 1
        var currentStreak = 1

        for date in activeDates.dropFirst() {
            let expectedDate = calendar.date(byAdding: .day, value: 1, to: previousDate)
            if let expectedDate, calendar.isDate(date, inSameDayAs: expectedDate) {
                currentStreak += 1
            } else if !calendar.isDate(date, inSameDayAs: previousDate) {
                currentStreak = 1
            }

            bestStreak = max(bestStreak, currentStreak)
            previousDate = date
        }

        return bestStreak
    }

    // Возвращает массив уровней активности (0-5) для Heatmap за 30 дней
    func getLast30Days() -> [Int] {
        let history = getHistory()
        let calendar = Calendar.current
        var result: [Int] = []

        for index in (0..<30).reversed() {
            let date = calendar.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            let dateStr = dateFormatter.string(from: date)
            let count = history[dateStr] ?? 0

            let level: Int
            if count == 0 {
                level = 0
            } else if count <= 3 {
                level = 1
            } else if count <= 6 {
                level = 2
            } else if count <= 9 {
                level = 3
            } else if count <= 15 {
                level = 4
            } else {
                level = 5
            }

            result.append(level)
        }
        return result
    }

    func getDailyActivity(days: Int) -> [DailyStudyActivity] {
        let history = getHistory()
        let calendar = Calendar.current

        return (0..<days).reversed().map { index in
            let date = calendar.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            let key = dateFormatter.string(from: date)
            return DailyStudyActivity(date: date, cards: history[key] ?? 0)
        }
    }

    func totalStudiedCards() -> Int {
        getHistory().values.reduce(0, +)
    }

    func totalActiveDays() -> Int {
        getHistory().values.filter { $0 > 0 }.count
    }

    // Рассчитывает сэкономленное время (предполагаем 2 минуты экономии на каждую карточку)
    func calculateSavedTimeHours() -> Int {
        let totalCards = totalStudiedCards()
        return (totalCards * 2) / 60
    }
}
