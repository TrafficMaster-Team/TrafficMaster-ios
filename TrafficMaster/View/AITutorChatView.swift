//
//  AITutorChatView.swift
//  TrafficMaster
//

import SwiftUI

struct AITutorChatView: View {
    @Environment(\.dismiss) private var dismiss

    let context: AITutorQuestionContext

    @State private var messages: [AITutorChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let client = OpenRouterClient.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatTranscript
                Divider()
                composer
            }
            .navigationTitle("AI-репетитор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadInitialExplanationIfNeeded()
            }
        }
    }

    private var chatTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    contextHeader

                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if isLoading {
                        loadingBubble
                            .id("loading")
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: isLoading) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var contextHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                context.isCorrect ? "Ответ верный" : "Разберем ошибку",
                systemImage: context.isCorrect ? "checkmark.seal.fill" : "xmark.seal.fill"
            )
            .font(.headline)
            .foregroundStyle(context.isCorrect ? .green : .red)

            Text(context.questionText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Ваш ответ: \(context.userAnswer)")
                Text("Правильный ответ: \(context.correctAnswer)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Спросить про правило", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                .disabled(isLoading)

            Button(action: {
                Task {
                    await sendUserMessage()
                }
            }, label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? Color.accentColor : Color.gray.opacity(0.55), in: Circle())
            })
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Отправить вопрос AI-репетитору")
        }
        .padding(12)
        .background(Color(uiColor: .systemBackground))
    }

    private var canSend: Bool {
        !isLoading && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var loadingBubble: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Готовлю объяснение...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageBubble(_ message: AITutorChatMessage) -> some View {
        let isUser = message.role == .user

        return Text(message.content)
            .font(.body)
            .foregroundStyle(isUser ? .white : .primary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isUser ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            .accessibilityLabel(isUser ? "Ваш вопрос" : "Ответ AI-репетитора")
    }

    private func errorBanner(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Не удалось получить ответ", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @MainActor
    private func loadInitialExplanationIfNeeded() async {
        guard messages.isEmpty else { return }
        await requestTutorResponse()
    }

    @MainActor
    private func sendUserMessage() async {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        inputText = ""
        messages.append(AITutorChatMessage(role: .user, content: trimmedText))
        await requestTutorResponse()
    }

    @MainActor
    private func requestTutorResponse() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let answer = try await client.sendTutorRequest(context: context, visibleMessages: messages)
            messages.append(AITutorChatMessage(role: .assistant, content: answer))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.snappy(duration: 0.2)) {
            if isLoading {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastID = messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

#Preview {
    AITutorChatView(
        context: AITutorQuestionContext(
            questionText: "Разрешено ли водителю выполнить разворот в этой ситуации?",
            imageName: nil,
            userAnswer: "Разрешено",
            correctAnswer: "Запрещено",
            allAnswers: ["Разрешено", "Запрещено"],
            isCorrect: false,
            explanation: nil,
            sectionTitle: "Маневрирование",
            chapterTitle: "Разворот"
        )
    )
}
