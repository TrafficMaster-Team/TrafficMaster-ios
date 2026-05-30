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
    var backendCardProgressID: UUID?
    var seenAt: Date?

    // Taxonomy
    var sectionTitle: String?
    var chapterTitle: String?

    // Backend SM-2 progress fields
    var sm2State: SM2CardState
    var repetitions: Int
    var interval: Int
    var easinessFactor: Double
    var nextReviewDate: Date

    // Deprecated local memory fields from older builds. They are kept only for SQLite migration compatibility.
    var stability: Double
    var difficulty: Double
    var retrievability: Double

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
        backendCardProgressID: UUID? = nil,
        seenAt: Date? = nil,
        sectionTitle: String? = "Раздел 1",
        chapterTitle: String? = "Глава 1",
        sm2State: SM2CardState = .new,
        repetitions: Int = 0,
        interval: Int = 1,
        easinessFactor: Double = 2.5,
        nextReviewDate: Date = Date(),
        stability: Double = 0.0,
        difficulty: Double = 5.0,
        retrievability: Double = 1.0
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
        self.backendCardProgressID = backendCardProgressID
        self.seenAt = seenAt
        self.sectionTitle = sectionTitle
        self.chapterTitle = chapterTitle
        self.sm2State = sm2State
        self.repetitions = repetitions
        self.interval = interval
        self.easinessFactor = easinessFactor
        self.nextReviewDate = nextReviewDate
        self.stability = stability
        self.difficulty = difficulty
        self.retrievability = retrievability
    }

    static func == (lhs: Question, rhs: Question) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Migration Support

    /// Called after model is loaded from store to ensure all values are valid.
    func validateAndFixDefaults() {
        if repetitions < 0 { repetitions = 0 }
        if interval < 1 { interval = 1 }
        if easinessFactor < 1.3 { easinessFactor = 2.5 }

        // Keep deprecated fields sane for old rows and old exported fixtures.
        if stability < 0 { stability = 0.0 }
        if difficulty <= 0 { difficulty = 5.0 }
        if retrievability < 0 || retrievability > 1 { retrievability = 1.0 }

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
