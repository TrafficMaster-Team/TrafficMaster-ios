//
//  QuestionViewModel.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import Foundation
import SwiftUI

@Observable
class QuestionViewModel {
    var allQuestions: [Question] = []
    var currentQuestion: Question?
    var shuffledOptions: [String] = []
    var selectedOptionIndex: Int?
    var isCorrect: Bool?
    var userAnswerIndex: Int?
    var showExplanation = false
    
    // Anki / Progress tracking
    var targetNewCards = 0
    var learnedTodayCount = 0
    var cardsToReviewCount = 0
    
    // Session Queue
    private var sessionQueue: [Question] = []
    
    // FSRS Scheduler (Domain Layer)
    private let fsrScheduler = FSRSScheduler()
    
    // Exam Mode
    private var examQueue: [Question] = []
    private var isExamMode = false
    private var isMarathon = false
    
    // Stats for UI (Stored properties to trigger SwiftUI updates)
    var blueCount: Int = 0
    var yellowCount: Int = 0
    var greenCount: Int = 0
    
    var dueTodayCount: Int {
        let now = Date()
        return allQuestions.filter { $0.repetitions > 0 && $0.nextReviewDate <= now }.count
    }
    
    var correctAnswerIndexInShuffled: Int? {
        guard let question = currentQuestion else { return nil }
        let correctText = question.options[question.correctAnswerIndex]
        return shuffledOptions.firstIndex(of: correctText)
    }
    
    var showGuessedButton: Bool {
        userAnswerIndex != nil && isCorrect == false
    }
    
    private func updateCounters() {
        var queue = sessionQueue
        if let current = currentQuestion {
            queue.append(current)
        }
        
        blueCount = queue.filter { $0.repetitions == 0 }.count
        yellowCount = queue.filter { $0.repetitions > 0 && $0.repetitions < 10 }.count
        greenCount = queue.filter { $0.repetitions >= 10 }.count
    }
    
    func loadQuestions(isMarathon: Bool = false, dailyNewLimit: Int = 20, isExamMode: Bool = false) {
        do {
            let questions = try DatabaseService.shared.fetchAllQuestions()
            self.allQuestions = questions
            self.isMarathon = isMarathon
            self.isExamMode = isExamMode
            self.targetNewCards = dailyNewLimit

            if isExamMode {
                setupExamSession()
            } else if isMarathon {
                setupMarathonSession()
            } else {
                setupStandardSession()
            }
            
            updateCounters()
        } catch {
            print("❌ Failed to load questions from SQLite: \(error)")
        }
    }
    
    private func setupExamSession() {
        examQueue = allQuestions.shuffled()
        loadNextExamQuestion()
    }
    
    private func loadNextExamQuestion() {
        guard !examQueue.isEmpty else {
            currentQuestion = nil
            return
        }
        let nextQuestion = examQueue.removeFirst()
        currentQuestion = nextQuestion
        shuffledOptions = nextQuestion.options.shuffled()
    }
    
    private func setupMarathonSession() {
        // Marathon mode: start with a fresh batch of strictly new questions
        let newQuestions = allQuestions.filter { $0.repetitions == 0 }.prefix(targetNewCards)
        
        sessionQueue = Array(newQuestions)
        sessionQueue.shuffle()
        
        cardsToReviewCount = 0
        loadNextFromQueue()
    }
    
    private func setupStandardSession() {
        let now = Date()
        let dueQuestions = allQuestions.filter { $0.repetitions > 0 && $0.nextReviewDate <= now }
        let newQuestions = allQuestions.filter { $0.repetitions == 0 }.prefix(targetNewCards)
        
        sessionQueue = Array(dueQuestions) + Array(newQuestions)
        sessionQueue.shuffle()
        
        cardsToReviewCount = dueQuestions.count
        loadNextFromQueue()
    }
    
    func loadMoreMarathonQuestions(count: Int = 20) {
        // Find strictly new questions (repetitions == 0) that aren't already in the queue
        var inQueueIds = Set(sessionQueue.map { $0.id })
        if let currentId = currentQuestion?.id {
            // Usually currentQuestion is nil when calling this, but just in case
            _ = inQueueIds.insert(currentId)
        }
        
        let additionalNew = allQuestions.filter { $0.repetitions == 0 && !inQueueIds.contains($0.id) }.prefix(count)
        
        sessionQueue.append(contentsOf: additionalNew)
        sessionQueue.shuffle()
        
        targetNewCards += count
        
        if currentQuestion == nil {
            loadNextFromQueue()
        }
    }
    
    private func loadNextFromQueue() {
        guard !sessionQueue.isEmpty else {
            currentQuestion = nil
            return
        }
        let next = sessionQueue.removeFirst()
        currentQuestion = next
        shuffledOptions = next.options.shuffled()
    }
    
    func selectAnswer(index: Int) {
        guard userAnswerIndex == nil else { return }
        userAnswerIndex = index
        selectedOptionIndex = index
        
        if index == correctAnswerIndexInShuffled {
            isCorrect = true
        } else {
            isCorrect = false
            showExplanation = true
        }
    }
    
    func continueToNext() {
        guard currentQuestion != nil, let isCorrect = isCorrect else { return }
        if isCorrect == true {
            applyFSRSRating(grade: .good)
        } else {
            applyFSRSRating(grade: .again)
        }
    }

    func markAsGuessed() {
        applyFSRSRating(grade: .good)
    }

    private func applyFSRSRating(grade: FSRSScheduler.Grade) {
        guard let question = currentQuestion else { return }

        if isExamMode {
            processExamReview(grade: grade)
            return
        }

        let cardState = FSRSScheduler.CardState(
            stability: question.stability,
            difficulty: question.difficulty,
            lastReviewDate: question.nextReviewDate,
            dueDate: question.nextReviewDate
        )

        let result = fsrScheduler.reviewCard(cardState: cardState, grade: grade)

        question.stability = result.stability
        question.difficulty = result.difficulty
        question.retrievability = result.retrievability
        question.nextReviewDate = result.nextReviewDate

        if grade == .good {
            question.repetitions += 1
            
            // If the question hasn't reached fully mastered (e.g. repetitions >= 10), we could put it back.
            // But in Anki, hitting 'good' on a new card puts it in learning. Let's say if repetitions < 2, 
            // we show it again in this session to ensure it's memorized.
            if isMarathon && question.repetitions < 2 {
                let insertIndex = min(sessionQueue.count, Int.random(in: 3...8))
                sessionQueue.insert(question, at: insertIndex)
            }
            
            loadNextFromQueue()
            learnedTodayCount += 1
        } else {
            question.repetitions = 0
            question.interval = 1
            
            let insertIndex = min(sessionQueue.count, Int.random(in: 2...6))
            sessionQueue.insert(question, at: insertIndex)
            
            loadNextFromQueue()
        }

        // Save to SQLite
        do {
            try DatabaseService.shared.saveQuestion(question)
            
            // Log to revlogs
            let revlog = Revlog(
                id: UUID(),
                cardId: question.id,
                reviewDatetime: Date(),
                grade: grade.rawValue,
                timeTaken: 0, // Should be measured
                preStability: cardState.stability,
                preDifficulty: cardState.difficulty
            )
            try DatabaseService.shared.saveRevlog(revlog)
            
        } catch {
            print("❌ SQLite Save error: \(error)")
        }
        
        ProgressTracker.shared.logCardStudied()
        updateCounters()
        resetSelection()
    }
    
    private func processExamReview(grade: FSRSScheduler.Grade) {
        guard let question = currentQuestion else { return }
        if grade == .again {
            let reinsertIndex = min(examQueue.count, Int.random(in: 15...40))
            examQueue.insert(question, at: reinsertIndex)
        }
        loadNextExamQuestion()
        resetSelection()
    }

    private func resetSelection() {
        userAnswerIndex = nil
        selectedOptionIndex = nil
        isCorrect = nil
        showExplanation = false
    }
}
