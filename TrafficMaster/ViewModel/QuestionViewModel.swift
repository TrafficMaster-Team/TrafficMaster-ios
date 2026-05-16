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
    private var shuffledAnswerOptions: [AnswerOption] = []
    var selectedOptionIndex: Int?
    var isCorrect: Bool?
    var userAnswerIndex: Int?
    var showExplanation = false
    private var questionShownAt: Date?
    
    // Anki / Progress tracking
    var targetNewCards = 0
    var learnedTodayCount = 0
    var cardsToReviewCount = 0
    
    // Session Queue
    private var sessionQueue: [Question] = []
    private var sessionCards: [Question] = [] // Tracks the full batch for UI counters
    
    // FSRS Scheduler (Domain Layer)
    private let fsrScheduler = FSRSScheduler()
    
    // Exam Mode
    private var examQueue: [Question] = []
    private var isExamMode = false
    
    // Stats for UI (Stored properties to trigger SwiftUI updates)
    var blueCount: Int = 0
    var yellowCount: Int = 0
    var greenCount: Int = 0
    
    var dueTodayCount: Int {
        let now = Date()
        return allQuestions.filter { $0.repetitions > 0 && $0.nextReviewDate <= now }.count
    }
    
    var introducedTodayCount: Int {
        let calendar = Calendar.current
        return allQuestions.filter { question in
            guard let seenAt = question.seenAt else { return false }
            return calendar.isDateInToday(seenAt)
        }.count
    }
    
    var correctAnswerIndexInShuffled: Int? {
        guard let question = currentQuestion else { return nil }
        if let explicitIndex = shuffledAnswerOptions.firstIndex(where: { $0.isCorrect == true }) {
            return explicitIndex
        }
        
        if let explicitCorrectID = question.answerOptions.first(where: { $0.isCorrect == true })?.id {
            return shuffledAnswerOptions.firstIndex(where: { $0.id == explicitCorrectID })
        }
        
        let correctText = question.options[question.correctAnswerIndex]
        return shuffledOptions.firstIndex(of: correctText)
    }
    
    var showGuessedButton: Bool {
        userAnswerIndex != nil && isCorrect == true
    }
    
    private func updateCounters() {
        // Anki-like tiers:
        // Blue: never seen, Red: seen but not yet graduated, Green: review/strengthening
        blueCount = sessionCards.filter { $0.seenAt == nil }.count
        yellowCount = sessionCards.filter { $0.seenAt != nil && $0.repetitions == 0 }.count
        greenCount = sessionCards.filter { $0.seenAt != nil && $0.repetitions > 0 }.count
    }
    
    func loadQuestions(dailyNewLimit: Int = 34, isExamMode: Bool = false) {
        do {
            print("📥 QuestionViewModel.loadQuestions() called")
            let questions = try DatabaseService.shared.fetchAllQuestions()
            print("✅ Successfully loaded \(questions.count) questions from SQLite")
            self.allQuestions = questions
            self.isExamMode = isExamMode
            self.targetNewCards = dailyNewLimit

            if isExamMode {
                setupExamSession()
            } else {
                setupStandardSession()
            }

            updateCounters()
            print("🎯 Session setup complete, sessionCards: \(sessionCards.count)")
        } catch {
            print("❌ Failed to load questions from SQLite: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
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
        prepareShuffledOptions(for: nextQuestion)
    }
    
    private func setupStandardSession() {
        let now = Date()
        
        // Continue-first strategy:
        // 1) Learning continuation (seen at least once, but not graduated)
        // 2) Due review cards
        // 3) Brand-new unseen cards
        let learningContinuation = allQuestions.filter { $0.seenAt != nil && $0.repetitions == 0 }
        let dueReview = allQuestions.filter { $0.seenAt != nil && $0.repetitions > 0 && $0.nextReviewDate <= now }
        
        // Hard daily cap for new cards:
        // if user already introduced N new cards today, do not exceed targetNewCards.
        let remainingNewToday = max(0, targetNewCards - introducedTodayCount)
        let newUnseen = allQuestions.filter { $0.seenAt == nil }.prefix(remainingNewToday)
        
        sessionCards = Array(learningContinuation) + Array(dueReview) + Array(newUnseen)
        sessionQueue = sessionCards
        sessionQueue.shuffle()
        
        cardsToReviewCount = learningContinuation.count + dueReview.count
        loadNextFromQueue()
    }
    
    private func loadNextFromQueue() {
        guard !sessionQueue.isEmpty else {
            currentQuestion = nil
            return
        }
        let next = sessionQueue.removeFirst()
        currentQuestion = next
        prepareShuffledOptions(for: next)
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
        applyFSRSRating(grade: .again)
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

        if grade == .again {
            question.repetitions = 0
            question.interval = 1
            
            // Re-insert failed question into queue
            let insertIndex = min(sessionQueue.count, Int.random(in: 2...6))
            sessionQueue.insert(question, at: insertIndex)
            
            loadNextFromQueue()
        } else {
            question.repetitions += 1
            
            loadNextFromQueue()
            learnedTodayCount += 1
        }
        
        question.interval = max(
            1,
            Calendar.current.dateComponents([.day], from: Date(), to: question.nextReviewDate).day ?? 1
        )

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
            
            let answeredAt = Date()
            let timeSpentMs = max(
                0,
                Int((answeredAt.timeIntervalSince(questionShownAt ?? answeredAt)) * 1000.0)
            )
            let syncEvent = SyncReviewEvent(
                id: UUID(),
                cardId: question.id,
                selectedOptionID: selectedOptionIDForCurrentSelection(),
                rating: mapGradeToReviewRating(grade),
                answeredAt: answeredAt,
                timeSpentMs: timeSpentMs,
                createdAt: answeredAt
            )
            try DatabaseService.shared.enqueueReviewEvent(syncEvent)
            
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
    
    private func prepareShuffledOptions(for question: Question) {
        if question.seenAt == nil {
            question.seenAt = Date()
            try? DatabaseService.shared.saveQuestion(question)
        }
        
        if !question.answerOptions.isEmpty {
            shuffledAnswerOptions = question.answerOptions.shuffled()
            shuffledOptions = shuffledAnswerOptions.map(\.text)
        } else {
            shuffledAnswerOptions = question.options.enumerated().map { idx, option in
                AnswerOption(
                    text: option,
                    isCorrect: idx == question.correctAnswerIndex,
                    order: idx
                )
            }.shuffled()
            shuffledOptions = shuffledAnswerOptions.map(\.text)
        }
        questionShownAt = Date()
        updateCounters()
    }
    
    private func selectedOptionIDForCurrentSelection() -> UUID? {
        guard let index = selectedOptionIndex,
              shuffledAnswerOptions.indices.contains(index) else {
            return nil
        }
        return shuffledAnswerOptions[index].id
    }
    
    private func mapGradeToReviewRating(_ grade: FSRSScheduler.Grade) -> ReviewRating {
        switch grade {
        case .again: return .again
        case .hard: return .hard
        case .good: return .good
        case .easy: return .easy
        }
    }
}
