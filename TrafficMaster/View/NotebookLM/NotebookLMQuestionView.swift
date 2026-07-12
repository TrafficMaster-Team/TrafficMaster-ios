import SwiftUI

struct NotebookLMQuestionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let topic: String
    let questions: [NotebookLMQuestion]
    
    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int?
    @State private var isAnswered: Bool = false
    @State private var showingExitAlert = false
    
    var currentQuestion: NotebookLMQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .secondarySystemGroupedBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if currentQuestion == nil {
                completionScreen
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            questionArea
                            optionsList()
                            
                            if isAnswered {
                                explanationArea
                            }
                            
                            Color.clear.frame(height: 120)
                        }
                        .safeAreaPadding(.top, 20)
                    }
                }
                
                if isAnswered {
                    actionButtons
                }
            }
        }
        .navigationTitle(topic)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                leadingToolbarContent
            }
        }
        .alert("Вы действительно хотите выйти?", isPresented: $showingExitAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Выйти", role: .destructive) { dismiss() }
        }
    }
    
    // MARK: - Subviews
    
    private var completionScreen: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
            
            Text("Отличная работа!")
                .font(.largeTitle.weight(.bold))
            
            Text("Вы ответили на все вопросы из этого раздела.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Haptics.impact(.medium)
                dismiss()
            }, label: {
                Text("Вернуться на главную")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            })
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .onAppear {
            Haptics.notification(.success)
        }
    }
    
    private var questionArea: some View {
        VStack(spacing: 16) {
            Text(currentQuestion?.question ?? "")
                .font(.system(.title3, design: .rounded, weight: .medium))
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }
    
    private func optionsList() -> some View {
        guard let question = currentQuestion else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(spacing: 12) {
                ForEach(Array(question.answerOptions.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedOptionIndex = index
                            isAnswered = true
                            
                            if option.isCorrect {
                                Haptics.notification(.success)
                            } else {
                                Haptics.notification(.error)
                            }
                        }
                    }, label: {
                        HStack(spacing: 0) {
                            Text("\(index + 1)")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44)
                                .frame(maxHeight: .infinity)
                                .background(Color.purple.opacity(0.6))
                            
                            Text(option.text)
                                .font(.system(.body, design: .rounded, weight: .regular))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if isAnswered {
                                Image(systemName: option.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(option.isCorrect ? .green : .red)
                                    .opacity((selectedOptionIndex == index || option.isCorrect) ? 1 : 0)
                                    .frame(width: 24, height: 24)
                                    .padding(.trailing, 16)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .background(optionBackground(for: index, option: option))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.purple.opacity(0.12), lineWidth: 1)
                        )
                    })
                    .disabled(isAnswered)
                    .buttonStyle(SquishyButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        )
    }
    
    private var explanationArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let hint = currentQuestion?.hint {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    Text(hint)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if let question = currentQuestion, let selected = selectedOptionIndex, selected < question.answerOptions.count {
                let option = question.answerOptions[selected]
                if let rationale = option.rationale {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(option.isCorrect ? "Правильно!" : "Упс, ошибка")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(option.isCorrect ? .green : .red)
                        
                        Text(rationale)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var actionButtons: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Button(action: {
                    Haptics.selection()
                    withAnimation(.spring()) {
                        currentIndex += 1
                        selectedOptionIndex = nil
                        isAnswered = false
                    }
                }, label: {
                    Text("Дальше")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.purple.opacity(0.25), radius: 8, x: 0, y: 4)
                })
                .buttonStyle(SquishyButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Color.clear)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private var leadingToolbarContent: some View {
        Button(action: {
            Haptics.selection()
            showingExitAlert = true
        }, label: {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: 36, height: 36)
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }
        })
        .buttonStyle(.plain)
    }
    
    private func optionBackground(for index: Int, option: NotebookLMAnswerOption) -> AnyShapeStyle {
        if isAnswered {
            if option.isCorrect {
                return AnyShapeStyle(Color.green.opacity(0.14))
            } else if index == selectedOptionIndex {
                return AnyShapeStyle(Color.red.opacity(0.14))
            }
        }
        return AnyShapeStyle(Color.purple.opacity(0.04)) // Purple tint as requested
    }
}
