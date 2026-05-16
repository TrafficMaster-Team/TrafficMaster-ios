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
    @State private var showSavedToast = false
    
    var questions: [Question] = []
    var dailyLimit: Int = 34
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if viewModel.currentQuestion == nil {
                completionScreen
            } else {
                // Основной интерфейс карточек
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            questionAndImageArea
                            
                            // Варианты ответов
                            if viewModel.currentQuestion != nil {
                                optionsList()
                            }
                            
                            // Anki-счетчики (Общий прогресс)
                            ankiCounters
                                .padding(.top, 8)
                            
                            // Пространство под плавающие кнопки
                            Color.clear.frame(height: 200)
                        }
                    }
                }
                
                // Плавающие кнопки действий
                if viewModel.userAnswerIndex != nil {
                    actionButtons
                }
                
                // Индикатор сохранения
                if showSavedToast {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "icloud.and.arrow.down.fill")
                            Text("Прогресс сохранен")
                        }
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                principalToolbarContent
            }
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
            viewModel.loadQuestions(dailyNewLimit: dailyLimit)
        }
    }
    
    // MARK: - Subviews
    
    private var completionScreen: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Отличная работа!")
                .font(.largeTitle.weight(.bold))
            
            let msg = "На сегодня карточки для этого раздела закончились. Возвращайтесь позже."
            
            Text(msg)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Button(action: {
                    Haptics.impact(.medium)
                    dismiss()
                }, label: {
                    Text("Вернуться на главную")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                })
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .onAppear {
            Haptics.notification(.success)
        }
    }
    
    private var questionAndImageArea: some View {
        VStack(spacing: 16) {
            // Картинка
            if let imageName = viewModel.currentQuestion?.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 16)
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
    }
    
    private func optionsList() -> some View {
        VStack(spacing: 12) {
            ForEach(Array(viewModel.shuffledOptions.enumerated()), id: \.offset) { index, option in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        viewModel.selectAnswer(index: index)

                        // Haptics based on correctness
                        if viewModel.isCorrect == true {
                            Haptics.notification(.success)
                        } else {
                            Haptics.notification(.error)
                        }
                    }
                }, label: {
                    HStack(spacing: 0) {
                        // Нумерация варианта (1, 2, 3, 4)
                        Text("\(index + 1)")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44)
                            .frame(maxHeight: .infinity)
                            .background(Color.gray.opacity(0.6))

                        // Текст варианта
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
                            .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                    )
                })
                .disabled(viewModel.userAnswerIndex != nil)
                .buttonStyle(SquishyButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var ankiCounters: some View {
        VStack(spacing: 8) {
            Text("ВАШ ПРОГРЕСС")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 24) {
                ankiCounterView(count: viewModel.blueCount, title: "Новые", color: .blue)
                ankiCounterView(count: viewModel.yellowCount, title: "В изучении", color: .red)
                ankiCounterView(count: viewModel.greenCount, title: "Закрепление", color: .green)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func ankiCounterView(count: Int, title: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    private var actionButtons: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                if viewModel.showGuessedButton {
                    guessedButton
                }
                
                continueButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(
                LinearGradient(
                    colors: [.clear, UIColor.systemBackground.color.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var guessedButton: some View {
        Button(action: {
            Haptics.impact(.medium)
            withAnimation(.spring()) {
                viewModel.markAsGuessed()
                triggerSaveToast()
            }
        }, label: {
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
        })
        .buttonStyle(SquishyButtonStyle())
        .transition(.scale.combined(with: .opacity))
    }
    
    private var continueButton: some View {
        Button(action: {
            Haptics.selection()
            withAnimation(.spring()) {
                viewModel.continueToNext()
                triggerSaveToast()
            }
        }, label: {
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
        })
        .buttonStyle(SquishyButtonStyle())
    }
    
    private func triggerSaveToast() {
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
    }
    
    private var principalToolbarContent: some View {
        Group {
            if let question = viewModel.currentQuestion {
                VStack(spacing: 2) {
                    Text(question.sectionTitle ?? "Раздел")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(question.chapterTitle ?? "Глава")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
    
    private var leadingToolbarContent: some View {
        Button(action: {
            Haptics.selection()
            showingExitAlert = true
        }, label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                Text("Назад")
                    .font(.body)
            }
            .foregroundColor(.primary)
        })
    }
    
    @ViewBuilder
    private var trailingToolbarContent: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                let totalTarget = viewModel.targetNewCards + viewModel.dueTodayCount
                Text("\(viewModel.learnedTodayCount)/\(totalTarget)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.2.circlepath")
                    .font(.caption2)
                Text("\(viewModel.dueTodayCount)")
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
            if index == viewModel.correctAnswerIndexInShuffled {
                return AnyShapeStyle(Color.green.opacity(0.14))
            } else if index == userIndex && viewModel.isCorrect == false {
                return AnyShapeStyle(Color.red.opacity(0.14))
            }
        }
        return AnyShapeStyle(Color(UIColor.secondarySystemBackground))
    }
}

// MARK: - Helper Views & Styles

struct MeshGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            
            glowCircle(color: .blue.opacity(0.15), width: 300, xOff: animate ? 100 : -100, yOff: animate ? -150 : 100)
            glowCircle(color: .purple.opacity(0.15), width: 300, xOff: animate ? -100 : 100, yOff: animate ? 150 : -100)
            glowCircle(color: .gray.opacity(0.1), width: 200, xOff: 0, yOff: animate ? -50 : 50)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
    
    private func glowCircle(color: Color, width: CGFloat, xOff: CGFloat, yOff: CGFloat) -> some View {
        Circle()
            .fill(color)
            .blur(radius: 60)
            .frame(width: width, height: width)
            .offset(x: xOff, y: yOff)
    }
}

struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Haptics Helper
struct Haptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
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
