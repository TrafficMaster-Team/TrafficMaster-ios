//
//  ExamModeConfiguration.swift
//  TrafficMaster
//
//  Data Layer - Exam Mode Configuration
//

import Foundation

/// Конфигурация предэкзаменационного режима
struct ExamModeConfiguration: Codable {
    /// Включён ли режим
    var isEnabled: Bool
    
    /// Дата экзамена (для расчёта дней до экзамена)
    var examDate: Date?
    
    /// Дневной лимит карточек в режиме экзамена
    var dailyCardLimit: Int
    
    /// Фильтровать ли по слабым темам
    var filterByWeakTopics: Bool
    
    /// Минимальное количество ошибок для попадания в «слабые темы»
    var minErrorsForWeakTopic: Int
    
    /// Приостановить ли SM-2 (не обновлять интервалы)
    var suspendSM2: Bool
    
    // MARK: - Presets
    
    /// Стандартная конфигурация (за 2 недели до экзамена)
    static let standardTwoWeeks = ExamModeConfiguration(
        isEnabled: true,
        examDate: Date().addingTimeInterval(14 * 24 * 60 * 60), // 14 дней
        dailyCardLimit: 400,
        filterByWeakTopics: false, // Показывать ВСЕ билеты
        minErrorsForWeakTopic: 3,
        suspendSM2: true
    )
    
    /// Интенсив (за 3 дня до экзамена)
    static let intensiveThreeDays = ExamModeConfiguration(
        isEnabled: true,
        examDate: Date().addingTimeInterval(3 * 24 * 60 * 60), // 3 дня
        dailyCardLimit: 600,
        filterByWeakTopics: true, // Только слабые темы
        minErrorsForWeakTopic: 2,
        suspendSM2: true
    )
    
    /// Обычный режим (не экзамен)
    static let normal = ExamModeConfiguration(
        isEnabled: false,
        examDate: nil,
        dailyCardLimit: 0,
        filterByWeakTopics: false,
        minErrorsForWeakTopic: 0,
        suspendSM2: false
    )
    
    // MARK: - Computed Properties
    
    /// Дней до экзамена
    var daysUntilExam: Int? {
        guard let examDate = examDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: examDate).day ?? 0
        return max(0, days)
    }
    
    /// Рекомендация по режиму
    var recommendation: ExamModeRecommendation {
        guard let days = daysUntilExam else { return .notSet }
        
        if days <= 3 {
            return .intensive
        } else if days <= 14 {
            return .standard
        } else {
            return .normal
        }
    }
}

// MARK: - Recommendation

enum ExamModeRecommendation: String {
    case notSet = "Дата экзамена не установлена"
    case normal = "Обычный режим обучения"
    case standard = "Стандартный предэкзаменационный (2 недели)"
    case intensive = "Интенсив (3 дня)"
}

// MARK: - Storage

class ExamModeStorage {
    private let defaults = UserDefaults.standard
    private let configKey = "exam_mode_configuration"
    
    func loadConfiguration() -> ExamModeConfiguration {
        guard let data = defaults.data(forKey: configKey),
              let config = try? JSONDecoder().decode(ExamModeConfiguration.self, from: data) else {
            return .normal
        }
        return config
    }
    
    func saveConfiguration(_ config: ExamModeConfiguration) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: configKey)
        }
    }
    
    func resetConfiguration() {
        defaults.removeObject(forKey: configKey)
    }
}
