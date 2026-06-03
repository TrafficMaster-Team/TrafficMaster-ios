//
//  AITutorChatView.swift
//  TrafficMaster
//

import SwiftUI

struct AITutorChatView: View {
    @Environment(\.dismiss) private var dismiss

    let context: AITutorQuestionContext
    @Binding var messages: [AITutorChatMessage]

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
                    disclaimerView

                    ForEach(visibleMessages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if isWaitingForFirstAssistantChunk {
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
            .onChange(of: latestMessageContent) { _, _ in
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

    private var disclaimerView: some View {
        Label("ИИ может ошибаться. Сверяйте спорные ответы с официальными ПДД РБ.", systemImage: "info.circle.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var latestMessageContent: String {
        messages.last?.content ?? ""
    }

    private var visibleMessages: [AITutorChatMessage] {
        messages.filter { message in
            message.role == .user || !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var isWaitingForFirstAssistantChunk: Bool {
        guard isLoading, let lastMessage = messages.last else { return false }
        return lastMessage.role == .assistant && lastMessage.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasCompletedAssistantAnswer: Bool {
        messages.contains { message in
            message.role == .assistant && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var loadingBubble: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Печатаю объяснение...")
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

        return messageBody(message)
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

    @ViewBuilder
    private func messageBody(_ message: AITutorChatMessage) -> some View {
        if message.role == .assistant {
            MarkdownText(markdown: message.content)
        } else {
            Text(message.content)
        }
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
        guard messages.isEmpty || !hasCompletedAssistantAnswer else { return }
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

        let requestMessages = messages
        let assistantID = UUID()
        messages.append(AITutorChatMessage(id: assistantID, role: .assistant, content: ""))

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.streamTutorRequest(context: context, visibleMessages: requestMessages) { chunk in
                await appendStreamingChunk(chunk, to: assistantID)
            }

            if messageContent(for: assistantID).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                removeMessage(id: assistantID)
                throw OpenRouterClientError.emptyResponse
            }
        } catch is CancellationError {
            if messageContent(for: assistantID).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                removeMessage(id: assistantID)
            }
        } catch {
            if messageContent(for: assistantID).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                removeMessage(id: assistantID)
            }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func appendStreamingChunk(_ chunk: String, to messageID: UUID) async {
        for character in chunk {
            appendToMessage(id: messageID, chunk: String(character))
            try? await Task.sleep(nanoseconds: 7_000_000)
        }
    }

    @MainActor
    private func appendToMessage(id: UUID, chunk: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        let message = messages[index]
        messages[index] = AITutorChatMessage(id: id, role: message.role, content: message.content + chunk)
    }

    @MainActor
    private func removeMessage(id: UUID) {
        messages.removeAll { $0.id == id }
    }

    private func messageContent(for id: UUID) -> String {
        messages.first(where: { $0.id == id })?.content ?? ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.snappy(duration: 0.2)) {
            if isWaitingForFirstAssistantChunk {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastID = visibleMessages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}

private struct MarkdownText: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: markdown) {
            Text(attributed)
        } else {
            Text(markdown)
        }
    }
}

#Preview {
    AITutorChatView(
        context: AITutorQuestionContext(
            id: "preview",
            questionText: "Разрешено ли водителю выполнить разворот в этой ситуации?",
            imageName: nil,
            userAnswer: "Разрешено",
            correctAnswer: "Запрещено",
            allAnswers: ["Разрешено", "Запрещено"],
            isCorrect: false,
            explanation: nil,
            sectionTitle: "Маневрирование",
            chapterTitle: "Разворот"
        ),
        messages: .constant([
            AITutorChatMessage(role: .assistant, content: "- **Коротко:** правильный ответ - запрещено.\n- Тема: разворот.")
        ])
    )
}
