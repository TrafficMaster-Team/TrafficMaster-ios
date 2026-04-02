//
//  ExamFilterService.swift
//  TrafficMaster
//
//  Domain Layer - Exam Filter Service
//

import Foundation

/// Сервис для управления предэкзаменационным режимом
class ExamFilterService {
    
    private let database: DatabaseService
    private var config: ExamModeConfiguration
    
    init(database: DatabaseService = .shared, config: ExamModeConfiguration = .normal) {
        self.database = database
        self.config = config
    }
    
    // MARK: - Configuration
    
    func updateConfiguration(_ newConfig: ExamModeConfiguration) {
        self.config = newConfig
    }
    
    // MARK: - Exam Queue Generation
    
    func generateExamQueue() throws -> [Question] {
        guard config.isEnabled else {
            throw ExamFilterError.modeNotEnabled
        }
        
        let allQuestions = try database.fetchAllQuestions()
        
        if config.filterByWeakTopics {
            return filterWeakTopics(from: allQuestions)
        } else {
            return allQuestions.shuffled()
        }
    }
    
    private func filterWeakTopics(from questions: [Question]) -> [Question] {
        return questions.filter { q in
            let isLowRetrievability = q.retrievability < 0.7
            let hasDifficulty = q.difficulty > 7.0
            return isLowRetrievability || hasDifficulty
        }.shuffled()
    }
    
    // MARK: - Review Processing
    
    func processReview(
        question: Question,
        isCorrect: Bool,
        currentQueue: inout [Question]
    ) {
        if !isCorrect {
            let reinsertIndex = min(currentQueue.count, Int.random(in: 10...30))
            currentQueue.insert(question, at: reinsertIndex)
        }
    }
    
    // MARK: - Statistics
    
    func getExamReadinessStats() throws -> ExamReadinessStats {
        let allQuestions = try database.fetchAllQuestions()
        
        let totalCards = allQuestions.count
        let masteredCards = allQuestions.filter { $0.retrievability >= 0.9 }.count
        let learningCards = allQuestions.filter { $0.retrievability >= 0.5 && $0.retrievability < 0.9 }.count
        let weakCards = allQuestions.filter { $0.retrievability < 0.5 }.count
        
        let avgRetrievability = allQuestions.isEmpty ? 0 : allQuestions.map { $0.retrievability }.reduce(0, +) / Double(allQuestions.count)
        
        return ExamReadinessStats(
            totalCards: totalCards,
            masteredCards: masteredCards,
            learningCards: learningCards,
            weakCards: weakCards,
            avgRetrievability: avgRetrievability,
            predictedSuccessRate: avgRetrievability,
            daysUntilExam: config.daysUntilExam,
            dailyCardLimit: config.dailyCardLimit
        )
    }
}

// MARK: - Statistics Models

struct ExamReadinessStats {
    let totalCards: Int
    let masteredCards: Int
    let learningCards: Int
    let weakCards: Int
    let avgRetrievability: Double
    let predictedSuccessRate: Double
    let daysUntilExam: Int?
    let dailyCardLimit: Int
    
    var masteryPercentage: Double {
        guard totalCards > 0 else { return 0 }
        return Double(masteredCards) / Double(totalCards) * 100
    }
    
    var readinessMessage: String {
        if predictedSuccessRate >= 0.95 {
            return "🎯 Отличная готовность! Шанс сдачи ~\(Int(predictedSuccessRate * 100))%"
        } else if predictedSuccessRate >= 0.85 {
            return "✅ Хорошая готовность. Повторите слабые темы."
        } else if predictedSuccessRate >= 0.7 {
            return "⚠️ Средняя готовность. Нужен интенсив."
        } else {
            return "❌ Низкая готовность. Требуется срочная подготовка."
        }
    }
}

struct ExamModeProgress {
    let isEnabled: Bool
    let daysUntilExam: Int?
    let recommendation: String
    let readinessStats: ExamReadinessStats?
}

enum ExamFilterError: LocalizedError {
    case modeNotEnabled
    case noCardsAvailable
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .modeNotEnabled: return "Предэкзаменационный режим не включён"
        case .noCardsAvailable: return "Нет карточек для повторения"
        case .invalidConfiguration: return "Некорректная конфигурация режима"
        }
    }
}
