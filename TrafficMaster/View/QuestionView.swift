//
//  QuestionView.swift
//  TrafficMaster
//
//  Created by Влад on 18.02.26.
//

import SwiftUI

struct QuestionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = QuestionViewModel()
    @State private var showingExitAlert = false
    var questions: [Question] = []
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            MeshGradientBackground()
                .ignoresSafeArea()
            
            if viewModel.currentQuestion == nil {
                // Экран завершения
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Отличная работа!")
                        .font(.largeTitle.weight(.bold))
                    
                    Text("На сегодня карточки для этого раздела закончились. Возвращайтесь позже.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: { dismiss() }) {
                        Text("Вернуться на главную")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 20)
                }
            } else {
                // Основной интерфейс карточек
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // Область вопроса и картинки
                            VStack(spacing: 16) {
                                // Картинка
                                if let _ = viewModel.currentQuestion?.imageData {
                                    imagePlaceholder
                                }
                                
                                // Текст вопроса
                                Text(viewModel.currentQuestion?.text ?? "Загрузка вопроса...")
                                    .font(.system(.title3, design: .rounded, weight: .medium))
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                            }
                            .padding(.top, 16)
                            
                            // Варианты ответов
                            if let question = viewModel.currentQuestion {
                                optionsList(question: question)
                            }
                            
                            // Пространство под плавающие кнопки
                            Color.clear.frame(height: 120)
                        }
                    }
                }
                
                // Плавающие кнопки действий (Ответил наугад / Дальше)
                if viewModel.userAnswerIndex != nil {
                    actionButtons
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                leadingToolbarContent
            }
            ToolbarItem(placement: .topBarTrailing) {
                trailingToolbarContent
            }
        }
        .alert("Вы действительно хотите выйти?", isPresented: $showingExitAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Выйти", role: .destructive) { dismiss() }
        }
        .onAppear {
            viewModel.loadQuestions(questions)
        }
        .onChange(of: questions) { _, newValue in
            viewModel.loadQuestions(newValue)
        }
    }
    
    // MARK: - Subviews
    
    private var imagePlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            
            Image(systemName: "car.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    private func optionsList(question: Question) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        viewModel.selectAnswer(index: index)
                    }
                }) {
                    HStack(spacing: 0) {
                        Text("\(index + 1)")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44)
                            .frame(maxHeight: .infinity)
                            .background(Color.gray.opacity(0.6))
                        
                        Text(option)
                            .font(.system(.body, design: .rounded, weight: .regular))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if viewModel.selectedOptionIndex == index {
                            Image(systemName: viewModel.isCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(viewModel.isCorrect == true ? .green : .red)
                                .padding(.trailing, 16)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .background(optionBackground(for: index))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                            .blendMode(.overlay)
                    )
                }
                .disabled(viewModel.userAnswerIndex != nil)
                .buttonStyle(SquishyButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var actionButtons: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                if viewModel.showGuessedButton {
                    Button(action: {
                        withAnimation(.spring()) {
                            viewModel.markAsGuessed()
                        }
                    }) {
                        Text("Ответил наугад 🤔")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }
                
                Button(action: {
                    withAnimation(.spring()) {
                        viewModel.continueToNext()
                    }
                }) {
                    Text("Дальше")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(SquishyButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(
                LinearGradient(colors: [.clear, UIColor.systemBackground.color.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var leadingToolbarContent: some View {
        Button(action: { showingExitAlert = true }) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                
                if let question = viewModel.currentQuestion {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(question.sectionTitle ?? "Раздел")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(question.chapterTitle ?? "Глава")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    private var trailingToolbarContent: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                let totalTarget = viewModel.targetNewCards + viewModel.cardsToReviewCount
                Text("\(viewModel.learnedTodayCount)/\(totalTarget)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.2.circlepath")
                    .font(.caption2)
                Text("\(viewModel.cardsToReviewCount)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            .foregroundColor(.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private func optionBackground(for index: Int) -> AnyShapeStyle {
        if let userIndex = viewModel.userAnswerIndex {
            if index == viewModel.currentQuestion?.correctAnswerIndex {
                return AnyShapeStyle(Color.green.opacity(0.2).shadow(.inner(color: .green.opacity(0.5), radius: 5)))
            } else if index == userIndex && viewModel.isCorrect == false {
                return AnyShapeStyle(Color.red.opacity(0.2).shadow(.inner(color: .red.opacity(0.5), radius: 5)))
            }
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }
}

// MARK: - Helper Views & Styles

struct ProgressHeaderView: View {
    let totalQuestions: Int
    let currentIndex: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Номера вопросов
                ForEach(0..<max(1, totalQuestions), id: \.self) { index in
                    Text("\(index + 1)")
                        .font(.system(.subheadline, design: .rounded, weight: index == currentIndex ? .bold : .medium))
                        .frame(width: 40, height: 36)
                        .background(index == currentIndex ? Color.primary.opacity(0.1) : Color.clear)
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct MeshGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            
            Circle()
                .fill(Color.blue.opacity(0.15))
                .blur(radius: 60)
                .frame(width: 300, height: 300)
                .offset(x: animate ? 100 : -100, y: animate ? -150 : 100)
            
            Circle()
                .fill(Color.purple.opacity(0.15))
                .blur(radius: 60)
                .frame(width: 300, height: 300)
                .offset(x: animate ? -100 : 100, y: animate ? 150 : -100)
            
            Circle()
                .fill(Color.gray.opacity(0.1))
                .blur(radius: 60)
                .frame(width: 200, height: 200)
                .offset(x: 0, y: animate ? -50 : 50)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// Extension to bridge UIColor to SwiftUI Color easily
extension UIColor {
    var color: Color {
        Color(self)
    }
}

#Preview {
    QuestionView(questions: [])
}
