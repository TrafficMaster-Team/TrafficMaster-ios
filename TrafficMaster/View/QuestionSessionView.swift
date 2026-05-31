import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct QuestionSessionView: View {
    @ObservedObject var viewModel: QuestionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isCompleted {
                    completionView
                } else if let question = viewModel.currentQuestion {
                    questionView(question: question)
                }
            }
            .navigationTitle("Сессия")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("На сегодня всё")
                .font(.title2.bold())
            Text("Сессия завершена. Вернись позже для новых повторений.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Готово") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func questionView(question: Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(question.chapterTitle ?? "Вопрос")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(question.text)
                    .font(.title3.weight(.medium))

                if let imageName = question.imageName {
                    questionImageView(imageName: imageName)
                }

                VStack(spacing: 10) {
                    ForEach(question.options) { option in
                        Button {
                            viewModel.selectOption(option.id)
                        } label: {
                            HStack {
                                Text(option.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let selected = viewModel.selectedOptionID, selected == option.id {
                                    Image(systemName: viewModel.isCorrectSelection ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(viewModel.isCorrectSelection ? .green : .red)
                                }
                            }
                            .padding(12)
                            .background(backgroundColor(for: option, question: question))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.revealedRating != nil)
                    }
                }

                if viewModel.isLoadingExplanation {
                    ProgressView("Генерация объяснения...")
                }

                if let explanation = viewModel.generatedExplanation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Разбор ошибки")
                            .font(.headline)
                        Text(explanation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if viewModel.revealedRating != nil {
                    actions
                }

                Text("Прогресс: \(viewModel.completedInSession) / \(viewModel.totalInSession)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if viewModel.isCorrectSelection {
                if viewModel.canUseEasy {
                    Button("Оценить как Easy") {
                        viewModel.revealedRating = .easy
                        viewModel.confirmCurrentAnswer()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Ответил наугад (Hard)") {
                    viewModel.applyGuessed()
                    viewModel.confirmCurrentAnswer()
                }
                .buttonStyle(.bordered)

                Button("Продолжить (Good)") {
                    viewModel.revealedRating = .good
                    viewModel.confirmCurrentAnswer()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Продолжить (Again)") {
                    viewModel.revealedRating = .again
                    viewModel.confirmCurrentAnswer()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func backgroundColor(for option: AnswerOption, question: Question) -> Color {
        guard let selected = viewModel.selectedOptionID else {
            return Color(uiColor: .secondarySystemBackground)
        }

        if option.id == question.correctOptionID {
            return Color.green.opacity(0.17)
        }

        if selected == option.id, selected != question.correctOptionID {
            return Color.red.opacity(0.17)
        }

        return Color(uiColor: .secondarySystemBackground)
    }

    @ViewBuilder
    private func questionImageView(imageName: String) -> some View {
#if canImport(UIKit)
        if let uiImage = UIImage(contentsOfFile: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
#else
        Image(imageName)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
#endif
    }
}
