//
//  InteractiveQuizView.swift
//  TrafficMasterClip
//
//  Created by Влад on 12/10/26.
//

import SwiftUI

struct InteractiveQuizView: View {
    @State private var currentStep: Int = 0
    @State private var selectedAnswerIndex: Int? = nil
    @State private var hasSubmitted: Bool = false
    @State private var correctAnswersCount: Int = 0
    @State private var isCompleted: Bool = false
    
    private let questions = DemoQuestionsRepository.questions
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isCompleted {
                    quizCompletionCard
                } else {
                    quizActiveCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Active Quiz Card
    
    private var quizActiveCard: some View {
        let question = questions[currentStep]
        
        return VStack(alignment: .leading, spacing: 18) {
            // Progress Bar & Step Counter
            VStack(spacing: 8) {
                HStack {
                    Text("Вопрос \(currentStep + 1) из \(questions.count)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Интерактивный тест")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(questions.count), height: 6)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .frame(height: 6)
            }
            
            // Topic & Question
            VStack(alignment: .leading, spacing: 8) {
                Label(question.topic, systemImage: question.iconName)
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                
                Text(question.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
            }
            
            // Options List
            VStack(spacing: 10) {
                ForEach(0..<question.options.count, id: \.self) { idx in
                    let isSelected = selectedAnswerIndex == idx
                    let isCorrect = idx == question.correctIndex
                    
                    Button {
                        if !hasSubmitted {
                            selectedAnswerIndex = idx
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        hasSubmitted
                                            ? (isCorrect ? Color.green : (isSelected ? Color.red : Color(uiColor: .tertiarySystemFill)))
                                            : (isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                                    )
                                    .frame(width: 28, height: 28)
                                
                                if hasSubmitted {
                                    Image(systemName: isCorrect ? "checkmark" : (isSelected ? "xmark" : ""))
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(isSelected ? .white : .secondary)
                                }
                            }
                            
                            Text(question.options[idx])
                                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    hasSubmitted
                                        ? (isCorrect ? Color.green.opacity(0.12) : (isSelected ? Color.red.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground)))
                                        : (isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    hasSubmitted
                                        ? (isCorrect ? Color.green : (isSelected ? Color.red : Color.clear))
                                        : (isSelected ? Color.accentColor : Color.clear),
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(hasSubmitted)
                }
            }
            
            // Insight Card on submission
            if hasSubmitted {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("ПОЧЕМУ ТАК:")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    Text(question.tmRuleMnemonic)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(14)
                .background(Color.yellow.opacity(0.12))
                .cornerRadius(12)
                .transition(.opacity)
            }
            
            // Action Button
            if !hasSubmitted {
                Button {
                    guard let selected = selectedAnswerIndex else { return }
                    hasSubmitted = true
                    if selected == question.correctIndex {
                        correctAnswersCount += 1
                    }
                } label: {
                    Text("Проверить ответ")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedAnswerIndex != nil ? Color.accentColor : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .disabled(selectedAnswerIndex == nil)
            } else {
                Button {
                    withAnimation(.spring()) {
                        if currentStep + 1 < questions.count {
                            currentStep += 1
                            selectedAnswerIndex = nil
                            hasSubmitted = false
                        } else {
                            isCompleted = true
                        }
                    }
                } label: {
                    HStack {
                        Text(currentStep + 1 < questions.count ? "Следующий вопрос" : "Посмотреть итог")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
    
    // MARK: - Quiz Completion Card
    
    private var quizCompletionCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
            }
            .padding(.top, 10)
            
            VStack(spacing: 6) {
                Text("Тест завершен!")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                
                Text("Результат: \(correctAnswersCount) из \(questions.count) правильных")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // SM-2 Learning Forecast
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.purple)
                    Text("РАСПИСАНИЕ SM-2 ДЛЯ ЭТИХ ВОПРОСОВ:")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                ForEach(questions) { q in
                    HStack {
                        Image(systemName: q.iconName)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        Text(q.topic)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                        
                        Spacer()
                        
                        Text("Повтор через \(q.tmDaysToNextReview) дн.")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.12))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(14)
            .background(Color(uiColor: .tertiarySystemFill))
            .cornerRadius(14)
            
            // Reset Button
            Button {
                withAnimation(.spring()) {
                    currentStep = 0
                    selectedAnswerIndex = nil
                    hasSubmitted = false
                    correctAnswersCount = 0
                    isCompleted = false
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Пройти еще раз")
                }
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundColor(.accentColor)
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
    }
}
