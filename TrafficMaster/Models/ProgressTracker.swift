//
//  ProgressTracker.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import Foundation

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
        return defaults.dictionary(forKey: historyKey) as? [String: Int] ?? [:]
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
        
        // Идем назад в прошлое
        var checkDate = calendar.date(byAdding: .day, value: -1, to: date)!
        while true {
            let dateStr = dateFormatter.string(from: checkDate)
            if let count = history[dateStr], count > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        return streak
    }
    
    // Возвращает массив уровней активности (0-5) для Heatmap за 30 дней
    func getLast30Days() -> [Int] {
        let history = getHistory()
        let calendar = Calendar.current
        var result: [Int] = []
        
        for i in (0..<30).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let dateStr = dateFormatter.string(from: date)
            let count = history[dateStr] ?? 0
            
            // Нормализация для красивой отрисовки от 0 до 5:
            // 0 карточек = 0, 1-3 = 1, 4-6 = 2, 7-9 = 3, 10-15 = 4, >15 = 5
            let level: Int
            if count == 0 { level = 0 }
            else if count <= 3 { level = 1 }
            else if count <= 6 { level = 2 }
            else if count <= 9 { level = 3 }
            else if count <= 15 { level = 4 }
            else { level = 5 }
            
            result.append(level)
        }
        return result
    }
    
    // Рассчитывает сэкономленное время (предполагаем 2 минуты экономии на каждую карточку)
    func calculateSavedTimeHours() -> Int {
        let history = getHistory()
        let totalCards = history.values.reduce(0, +)
        return (totalCards * 2) / 60
    }
}
