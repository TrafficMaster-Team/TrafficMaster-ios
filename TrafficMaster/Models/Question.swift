//
//  Question.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftData
import Foundation

@Model
class Question {
    var id: UUID
    var text: String
    var options: [String]
    var correctAnswerIndex: Int
    var explanation: String?
    var imageData: Data?
    
    // Taxonomy
    var sectionTitle: String?
    var chapterTitle: String?
    
    // SM-2 Algorithm variables
    var repetitions: Int
    var interval: Int
    var easinessFactor: Double
    var nextReviewDate: Date

    init(text: String, options: [String], correctAnswerIndex: Int, explanation: String? = nil, imageData: Data? = nil, sectionTitle: String? = "Раздел 1", chapterTitle: String? = "Глава 1") {
        self.id = UUID()
        self.text = text
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
        self.imageData = imageData
        self.sectionTitle = sectionTitle
        self.chapterTitle = chapterTitle
        
        // Default SM-2 values
        self.repetitions = 0
        self.interval = 1
        self.easinessFactor = 2.5
        self.nextReviewDate = Date()
    }
}

// MARK: - Backend Export (FastAPI)
extension Question {
    /// DTO (Data Transfer Object) для выгрузки данных на сервер FastAPI
    struct DTO: Codable {
        let id: UUID
        let text: String
        let options: [String]
        let correctAnswerIndex: Int
        let repetitions: Int
        let interval: Int
        let easinessFactor: Double
        let nextReviewDate: Date
    }
    
    var asDTO: DTO {
        DTO(
            id: id,
            text: text,
            options: options,
            correctAnswerIndex: correctAnswerIndex,
            repetitions: repetitions,
            interval: interval,
            easinessFactor: easinessFactor,
            nextReviewDate: nextReviewDate
        )
    }
}
