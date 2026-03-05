//
//  QuestionViewModel.swift
//  TrafficMaster
//
//  Created by Влад on 20.02.26.
//

import SwiftUI

@Observable
class QuestionViewModel {
    var currentQuestion: Question?
    var userAnswerIndex: Int?
    var isCorrect: Bool?
    var showGuessedButton: Bool = false
    var selectedOptionIndex: Int?
    
    // Временное хранилище
    var allQuestions: [Question] = []
    var sessionQuestions: [Question] = [] // Текущая очередь вопросов для сессии
    var currentIndex: Int = 0
    
    // Трекинг времени
    var questionStartTime: Date?
    var timeSpentOnCurrentQuestion: TimeInterval = 0
    
    // Статистика
    var learnedTodayCount: Int = 0
    var targetNewCards: Int = 0
    var cardsToReviewCount: Int = 0
    
    func loadQuestions(_ questions: [Question]) {
        // Загружаем только один раз при входе
        if !self.allQuestions.isEmpty { return }
        
        self.allQuestions = questions
        
        // Формируем очередь для изучения:
        // 1. Новые карточки (repetitions == 0)
        // 2. Карточки на повторение (nextReviewDate <= сейчас)
        let now = Date()
        let newCards = questions.filter { $0.repetitions == 0 }
        let reviewCards = questions.filter { $0.repetitions > 0 && $0.nextReviewDate <= now }
        
        // Перемешиваем и создаем сессию
        self.sessionQuestions = (newCards + reviewCards).shuffled()
        
        self.targetNewCards = newCards.count
        self.cardsToReviewCount = reviewCards.count
        self.learnedTodayCount = 0
        
        loadNextQuestionFromSession()
    }
    
    func selectAnswer(index: Int) {
        guard userAnswerIndex == nil else { return } // Запрещаем повторный выбор
        
        // Считаем время, затраченное на вопрос
        if let startTime = questionStartTime {
            timeSpentOnCurrentQuestion = Date().timeIntervalSince(startTime)
            print("Время на ответ: \(String(format: "%.1f", timeSpentOnCurrentQuestion)) сек.")
        }
        
        selectedOptionIndex = index
        userAnswerIndex = index
        
        if index == currentQuestion?.correctAnswerIndex {
            isCorrect = true
            showGuessedButton = true // Показываем кнопку "Ответил наугад"
        } else {
            isCorrect = false
            showGuessedButton = false
            applySM2(quality: 1) // Неверный ответ -> Качество 1
        }
    }
    
    func markAsGuessed() {
        showGuessedButton = false
        applySM2(quality: 3) // Угадал -> Качество 3
        processQuestionResultAndMoveToNext()
    }
    
    func continueToNext() {
        if isCorrect == true && showGuessedButton {
            applySM2(quality: 5)
        }
        processQuestionResultAndMoveToNext()
    }
    
    private func processQuestionResultAndMoveToNext() {
        guard let current = currentQuestion else { return }
        
        // Если вопрос отвечен правильно (SM-2 Quality >= 3), он "выучен" на сегодня.
        // Иначе (ошибка, Quality < 3), он остается в очереди и будет показан снова (уходит в конец).
        
        if isCorrect == true {
            learnedTodayCount += 1
            // Удаляем из текущей сессии
            if !sessionQuestions.isEmpty {
                sessionQuestions.removeFirst()
            }
        } else {
            // Переносим в конец очереди для повторения
            if !sessionQuestions.isEmpty {
                let failedCard = sessionQuestions.removeFirst()
                sessionQuestions.append(failedCard)
            }
        }
        
        userAnswerIndex = nil
        isCorrect = nil
        showGuessedButton = false
        selectedOptionIndex = nil
        
        loadNextQuestionFromSession()
    }
    
    private func loadNextQuestionFromSession() {
        if !sessionQuestions.isEmpty {
            currentQuestion = sessionQuestions.first
            questionStartTime = Date() // Сбрасываем таймер для нового вопроса
        } else {
            // Сессия завершена
            currentQuestion = nil
        }
    }
    
    private func applySM2(quality: Int) {
        guard let question = currentQuestion else { return }
        
        if quality >= 3 {
            if question.repetitions == 0 {
                question.interval = 1
            } else if question.repetitions == 1 {
                question.interval = 6
            } else {
                question.interval = Int(round(Double(question.interval) * question.easinessFactor))
            }
            question.repetitions += 1
        } else {
            question.repetitions = 0
            question.interval = 1
        }
        
        question.easinessFactor = question.easinessFactor + (0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02))
        if question.easinessFactor < 1.3 {
            question.easinessFactor = 1.3
        }
        
        question.nextReviewDate = Calendar.current.date(byAdding: .day, value: question.interval, to: Date()) ?? Date()
    }
}
