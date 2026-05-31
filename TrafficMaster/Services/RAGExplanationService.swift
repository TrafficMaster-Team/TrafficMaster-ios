import Foundation
#if canImport(UIKit)
import UIKit
#endif

final class RAGExplanationService {
    static let shared = RAGExplanationService()

    private let database: DatabaseService

    init(database: DatabaseService = .shared) {
        self.database = database
    }

    func explanationForMistake(
        question: Question,
        chosenOption: AnswerOption,
        settings: StudySettings,
        includeImageContext: Bool
    ) async -> String {
        if let cached = try? database.cachedExplanation(questionID: question.id, chosenOptionID: chosenOption.id) {
            return cached
        }

        let correct = question.options.first(where: { $0.id == question.correctOptionID })
        let retrievalQuery = makeRetrievalQuery(question: question, chosenOption: chosenOption, correctOption: correct)
        let chunks = (try? database.searchRules(query: retrievalQuery, limit: 6)) ?? []

        let localFallback = localFallbackExplanation(
            question: question,
            chosenOption: chosenOption,
            correctOption: correct,
            chunks: chunks
        )

        guard settings.aiExplanationsEnabled,
              let apiKey = KeychainService.loadOpenRouterKey(),
              !apiKey.isEmpty
        else {
            return localFallback
        }

        do {
            let generated = try await generateWithOpenRouter(
                apiKey: apiKey,
                model: settings.openRouterModel,
                question: question,
                chosenOption: chosenOption,
                correctOption: correct,
                chunks: chunks,
                includeImageContext: includeImageContext,
                imageName: question.imageName
            )
            try? database.cacheExplanation(questionID: question.id, chosenOptionID: chosenOption.id, explanation: generated)
            return generated
        } catch {
            return localFallback
        }
    }

    private func makeRetrievalQuery(question: Question, chosenOption: AnswerOption, correctOption: AnswerOption?) -> String {
        [
            question.chapterTitle,
            question.sectionTitle,
            question.text,
            chosenOption.text,
            correctOption?.text
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func localFallbackExplanation(
        question: Question,
        chosenOption: AnswerOption,
        correctOption: AnswerOption?,
        chunks: [LocalRuleChunk]
    ) -> String {
        let ruleSnippets = chunks.prefix(3).enumerated().map { idx, chunk in
            "\(idx + 1). [\(chunk.source)] \(chunk.title): \(chunk.text)"
        }.joined(separator: "\n")

        let correctText = correctOption?.text ?? "Нет данных"
        let base = question.explanation ?? "Проверь формулировку вопроса и нормативные условия применения правила."

        return """
        Правильный ответ: \(correctText)
        Выбранный ответ: \(chosenOption.text)

        Почему это ошибка:
        \(base)

        Полезные нормы для повторения:
        \(ruleSnippets.isEmpty ? "Нормы не найдены в локальной базе." : ruleSnippets)
        """
    }

    private func generateWithOpenRouter(
        apiKey: String,
        model: String,
        question: Question,
        chosenOption: AnswerOption,
        correctOption: AnswerOption?,
        chunks: [LocalRuleChunk],
        includeImageContext: Bool,
        imageName: String?
    ) async throws -> String {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let chunksText = chunks.prefix(6).map { "[\($0.source)] \($0.title): \($0.text)" }.joined(separator: "\n")
        let correctText = correctOption?.text ?? "Нет данных"
        let imageHint = includeImageContext ? "В вопросе есть изображение, учитывай визуальный контекст." : "Изображение не используется."

        let prompt = """
        Ты объясняешь ошибку ученику, который готовится к экзамену ГАИ РБ.
        Дай краткое, практичное объяснение:
        1) почему выбранный вариант неверен;
        2) почему правильный вариант верен;
        3) как запомнить правило (1-2 мнемоники).

        Вопрос: \(question.text)
        Выбранный ответ: \(chosenOption.text)
        Правильный ответ: \(correctText)
        Контекст: \(imageHint)

        Нормативные фрагменты:
        \(chunksText)
        """

        let userContent: Any
        if includeImageContext, let imageDataURL = loadImageDataURL(named: imageName) {
            userContent = [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": imageDataURL]]
            ]
        } else {
            userContent = prompt
        }

        let body: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": "Ты строгий преподаватель ПДД Республики Беларусь."],
                ["role": "user", "content": userContent]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        let text = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return text
    }

    private func loadImageDataURL(named imageName: String?) -> String? {
        guard let imageName else { return nil }
#if canImport(UIKit)
        let image = UIImage(contentsOfFile: imageName) ?? UIImage(named: imageName)
        guard let image,
              let data = image.jpegData(compressionQuality: 0.8)
        else { return nil }
        return "data:image/jpeg;base64,\(data.base64EncodedString())"
#else
        return nil
#endif
    }
}

private struct OpenRouterResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }

    let choices: [Choice]
}
