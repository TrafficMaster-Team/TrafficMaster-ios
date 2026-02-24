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
    var repetitions: Int
    var interval: Int
    var easinessFactor: Double
    var nextReviewDate: Date

    init(text: String, options: [String], correctAnswerIndex: Int, explanation: String? = nil) {
        self.id = UUID()
        self.text = text
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
        self.repetitions = 0
        self.interval = 1
        self.easinessFactor = 2.5
        self.nextReviewDate = Date()
    }
}
