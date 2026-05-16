//
//  Question.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import Foundation

struct AnswerOption: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var text: String
    var isCorrect: Bool?
    var order: Int?

    init(
        id: UUID = UUID(),
        text: String,
        isCorrect: Bool? = nil,
        order: Int? = nil
    ) {
        self.id = id
        self.text = text
        self.isCorrect = isCorrect
        self.order = order
    }
}

final class Question: Codable, Identifiable, Equatable, @unchecked Sendable {
    var id: UUID
    var text: String
    var options: [String]
    var answerOptions: [AnswerOption]
    var correctAnswerIndex: Int
    var explanation: String?
    var imageName: String?
    var backendCardID: UUID?
    var backendDeckID: UUID?

    // Taxonomy
    var sectionTitle: String?
    var chapterTitle: String?

    // FSRS Algorithm variables (DSR Model)
    var stability: Double         // How long the memory will last before forgetting
    var difficulty: Double        // How difficult the card is to learn
    var retrievability: Double    // Current probability of recall
    
    // Legacy SM-2 variables (for backward compatibility during migration)
    var repetitions: Int
    var interval: Int
    var easinessFactor: Double
    var nextReviewDate: Date

    init(
        id: UUID = UUID(),
        text: String,
        options: [String],
        answerOptions: [AnswerOption] = [],
        correctAnswerIndex: Int,
        explanation: String? = nil,
        imageName: String? = nil,
        backendCardID: UUID? = nil,
        backendDeckID: UUID? = nil,
        sectionTitle: String? = "Раздел 1",
        chapterTitle: String? = "Глава 1",
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        retrievability: Double = 1.0,
        repetitions: Int = 0,
        interval: Int = 1,
        easinessFactor: Double = 2.5,
        nextReviewDate: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.options = options
        self.answerOptions = answerOptions
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
        self.imageName = imageName
        self.backendCardID = backendCardID
        self.backendDeckID = backendDeckID
        self.sectionTitle = sectionTitle
        self.chapterTitle = chapterTitle

        // FSRS values
        self.stability = stability
        self.difficulty = difficulty
        self.retrievability = retrievability
        
        // SM-2 values
        self.repetitions = repetitions
        self.interval = interval
        self.easinessFactor = easinessFactor
        self.nextReviewDate = nextReviewDate
    }
    
    static func == (lhs: Question, rhs: Question) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Migration Support

    /// Called after model is loaded from store to ensure all values are valid
    func validateAndFixDefaults() {
        // Fix invalid FSRS values from old migrations
        if stability < 0 { stability = 0.0 }
        if difficulty <= 0 { difficulty = 5.0 }
        if retrievability < 0 || retrievability > 1 { retrievability = 1.0 }

        // Fix invalid SM-2 values
        if repetitions < 0 { repetitions = 0 }
        if interval < 0 { interval = 1 }
        if easinessFactor < 1.3 { easinessFactor = 2.5 }
        
        // Ensure multiple-choice payload always exists for backend-compatible flow.
        if answerOptions.isEmpty && !options.isEmpty {
            answerOptions = options.enumerated().map { index, text in
                AnswerOption(
                    text: text,
                    isCorrect: index == correctAnswerIndex,
                    order: index
                )
            }
        }
    }
}
