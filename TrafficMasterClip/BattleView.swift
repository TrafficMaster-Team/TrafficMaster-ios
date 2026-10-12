//
//  BattleView.swift
//  TrafficMasterClip
//
//  Created by Влад on 12/10/26.
//

import SwiftUI

struct BattleView: View {
    @State private var selectedQuestionIndex: Int = 0
    @State private var currentStyle: StudyExperienceStyle = .trafficMaster
    @State private var selectedOptionIndex: Int? = nil
    @State private var showingAiExplanation: Bool = false
    
    private var question: DemoQuestion {
        DemoQuestionsRepository.questions[selectedQuestionIndex]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Question selector pills
                questionSelector
                
                // Mode Toggle Header (ADrive vs TrafficMaster)
                styleToggleHeader
                
                // Question Card (styled according to selected mode)
                if currentStyle == .adrive {
                    adriveExperienceCard
                } else {
                    trafficMasterExperienceCard
                }
                
                // Live Impact Comparison Summary
                comparisonSummaryCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Subviews
    
    private var questionSelector: some View {
        HStack(spacing: 8) {
            ForEach(0..<DemoQuestionsRepository.questions.count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedQuestionIndex = index
                        selectedOptionIndex = nil
                        showingAiExplanation = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: DemoQuestionsRepository.questions[index].iconName)
                            .font(.caption2)
                        Text("Кейс \(index + 1)")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedQuestionIndex == index
                            ? Color.accentColor
                            : Color(uiColor: .secondarySystemBackground)
                    )
                    .foregroundColor(selectedQuestionIndex == index ? .white : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var styleToggleHeader: some View {
        VStack(spacing: 8) {
            Text("СРАВНЕНИЕ В РЕАЛЬНОМ ВРЕМЕНИ:")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        currentStyle = .adrive
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.dashed")
                        Text("Классика (ADrive)")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(currentStyle == .adrive ? Color.gray.opacity(0.25) : Color.clear)
                    .foregroundColor(currentStyle == .adrive ? .primary : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        currentStyle = .trafficMaster
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("TrafficMaster")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(currentStyle == .trafficMaster ? Color.accentColor : Color.clear)
                    .foregroundColor(currentStyle == .trafficMaster ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    // MARK: - ADrive Mode (Legacy / Classic)
    
    private var adriveExperienceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Билет 18, Вопрос 4 (ADrive / Стандартные тесты)", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Режим зубрёжки")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .clipShape(Capsule())
            }
            
            Text(question.title)
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.primary)
                .lineSpacing(3)
            
            // Options
            VStack(spacing: 8) {
                ForEach(0..<question.options.count, id: \.self) { idx in
                    Button {
                        selectedOptionIndex = idx
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1).")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                            Text(question.options[idx])
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedOptionIndex == idx
                                ? (idx == question.correctIndex ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                : Color(uiColor: .systemGray6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedOptionIndex == idx
                                        ? (idx == question.correctIndex ? Color.green : Color.red)
                                        : Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Explanation (Law quote)
            if selectedOptionIndex != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Официальный комментарий:")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(question.adriveLawParagraph)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color(uiColor: .systemGray5))
                        .cornerRadius(8)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis")
                        Text(question.adriveFrustrationRate)
                    }
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.top, 4)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - TrafficMaster Mode (Smart AI + SM-2)
    
    private var trafficMasterExperienceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label(question.topic, systemImage: question.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.accentColor)
                Spacer()
                Text(question.difficulty)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }
            
            Text(question.title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .lineSpacing(4)
            
            // Options list with modern feedback
            VStack(spacing: 10) {
                ForEach(0..<question.options.count, id: \.self) { idx in
                    let isSelected = selectedOptionIndex == idx
                    let isCorrect = idx == question.correctIndex
                    
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedOptionIndex = idx
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        isSelected
                                            ? (isCorrect ? Color.green : Color.red)
                                            : Color(uiColor: .tertiarySystemFill)
                                    )
                                    .frame(width: 28, height: 28)
                                
                                if isSelected {
                                    Image(systemName: isCorrect ? "checkmark" : "xmark")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
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
                                    isSelected
                                        ? (isCorrect ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                                        : Color(uiColor: .secondarySystemGroupedBackground)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isSelected
                                        ? (isCorrect ? Color.green : Color.red)
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // TrafficMaster Smart Insights
            if selectedOptionIndex != nil {
                VStack(alignment: .leading, spacing: 14) {
                    // Mnemonic Key Box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.yellow)
                            Text("МНЕМОНИЧЕСКИЙ ЧИТ-КОД")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(question.tmMemoryBoost)
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                        }
                        
                        Text(question.tmRuleMnemonic)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.primary)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .background(Color.yellow.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
                    
                    // SM-2 Algorithm Preview Card
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Алгоритм интервального повторения SM-2:")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                            Text("Следующий показ через \(question.tmDaysToNextReview) дней")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        Spacer()
                        Text("Ease 2.50")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                    .padding(12)
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(12)
                    
                    // AI Tutor Button & Expansion
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.spring()) {
                                showingAiExplanation.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "bubble.left.and.sparkles.fill")
                                    .foregroundColor(.accentColor)
                                Text(showingAiExplanation ? "Скрыть разбор AI-тьютора" : "Как это объясняет AI-тьютор?")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                Spacer()
                                Image(systemName: showingAiExplanation ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(.accentColor)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        
                        if showingAiExplanation {
                            Text(question.tmAiExplanation)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(12)
                                .background(Color(uiColor: .tertiarySystemFill))
                                .cornerRadius(10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Comparison Summary
    
    private var comparisonSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("СРАВНЕНИЕ ЭФФЕКТИВНОСТИ:")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Классика (ADrive)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("\(question.adriveStudyTimeMinutes) мин")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.red)
                    Text("на заучивание пункта")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.red.opacity(0.08))
                .cornerRadius(12)
                
                Image(systemName: "arrow.right")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 4) {
                    Text("TrafficMaster")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.accentColor)
                    Text("3 мин")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.green)
                    Text("понимание логики")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}
