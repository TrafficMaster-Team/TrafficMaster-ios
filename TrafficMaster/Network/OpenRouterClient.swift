//
//  OpenRouterClient.swift
//  TrafficMaster
//

import Foundation
import UIKit

struct AITutorQuestionContext: Identifiable, Sendable {
    let id = UUID()
    let questionText: String
    let imageName: String?
    let userAnswer: String
    let correctAnswer: String
    let allAnswers: [String]
    let isCorrect: Bool
    let explanation: String?
    let sectionTitle: String?
    let chapterTitle: String?
}

struct AITutorChatMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

final class OpenRouterClient {
    static let shared = OpenRouterClient()

    private let apiKey = "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"
    private let model = "xiaomi/mimo-v2.5"
    private let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sendTutorRequest(
        context: AITutorQuestionContext,
        visibleMessages: [AITutorChatMessage]
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenRouterClientError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("TrafficMaster", forHTTPHeaderField: "X-Title")
        request.setValue("https://trafficmaster.local", forHTTPHeaderField: "HTTP-Referer")

        let payload = OpenRouterChatRequest(
            model: model,
            messages: makeMessages(context: context, visibleMessages: visibleMessages),
            temperature: 0.25,
            maxTokens: 900
        )
        let requestBody = try encoder.encode(payload)
        let (data, response) = try await session.upload(for: request, from: requestBody)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenRouterClientError.serverStatus(httpResponse.statusCode, body)
        }

        let decoded = try decoder.decode(OpenRouterChatResponse.self, from: data)
        guard let answer = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !answer.isEmpty else {
            throw OpenRouterClientError.emptyResponse
        }
        return answer
    }

    private func makeMessages(
        context: AITutorQuestionContext,
        visibleMessages: [AITutorChatMessage]
    ) -> [OpenRouterChatMessage] {
        var messages: [OpenRouterChatMessage] = [
            OpenRouterChatMessage(role: "system", content: .text(systemPrompt))
        ]

        let contextText = makeContextPrompt(context)
        var contentParts = [OpenRouterContentPart.text(contextText)]
        if let dataURL = imageDataURL(named: context.imageName) {
            contentParts.append(.imageURL(dataURL))
        }

        messages.append(OpenRouterChatMessage(role: "user", content: .parts(contentParts)))

        for message in visibleMessages {
            messages.append(
                OpenRouterChatMessage(
                    role: message.role.rawValue,
                    content: .text(message.content)
                )
            )
        }

        return messages
    }

    private var systemPrompt: String {
        """
        Ты AI-репетитор приложения TrafficMaster для подготовки к экзамену по ПДД Республики Беларусь.
        Отвечай по-русски, спокойно и понятно. Объясняй логику правила, а не просто называй правильный вариант.
        Если пользователь ошибся, сначала коротко объясни, почему его ответ неверный, затем почему правильный ответ верный.
        Если пользователь ответил правильно, закрепи правило и объясни, на что смотреть в похожих вопросах.
        Указывай пункты или темы ПДД РБ только когда можешь уверенно определить их по вопросу и изображению.
        Если точный пункт неочевиден, честно напиши "по смыслу правила" и назови тему без выдуманного номера.
        Не давай юридических обещаний; формулируй как учебное объяснение для экзамена.
        """
    }

    private func makeContextPrompt(_ context: AITutorQuestionContext) -> String {
        let resultText = context.isCorrect ? "Пользователь ответил правильно." : "Пользователь ответил неправильно."
        let answersText = context.allAnswers.enumerated()
            .map { index, answer in "\(index + 1). \(answer)" }
            .joined(separator: "\n")
        let localExplanation = context.explanation?.trimmingCharacters(in: .whitespacesAndNewlines)
        let explanationText = localExplanation?.isEmpty == false ? localExplanation! : "В карточке нет локального пояснения."

        return """
        Разбери этот экзаменационный вопрос по ПДД РБ.

        Раздел: \(context.sectionTitle ?? "не указан")
        Глава: \(context.chapterTitle ?? "не указана")

        Вопрос:
        \(context.questionText)

        Варианты ответа:
        \(answersText)

        Ответ пользователя:
        \(context.userAnswer)

        Правильный ответ:
        \(context.correctAnswer)

        Результат:
        \(resultText)

        Локальное пояснение из базы:
        \(explanationText)

        Дай структурированный ответ:
        1. Короткий вывод.
        2. Почему так по ПДД РБ.
        3. Какие пункты или темы правил задействованы.
        4. Как запомнить для экзамена.
        """
    }

    private func imageDataURL(named imageName: String?) -> String? {
        guard let imageName,
              let image = UIImage(named: imageName),
              let imageData = scaledJPEGData(from: image) else {
            return nil
        }
        return "data:image/jpeg;base64,\(imageData.base64EncodedString())"
    }

    private func scaledJPEGData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1_200
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.82)
        }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return scaledImage.jpegData(compressionQuality: 0.82)
    }
}

enum OpenRouterClientError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case serverStatus(Int, String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Не задан ключ OpenRouter."
        case .invalidResponse:
            "OpenRouter вернул некорректный ответ."
        case let .serverStatus(statusCode, body):
            "OpenRouter вернул статус \(statusCode). \(body)"
        case .emptyResponse:
            "OpenRouter вернул пустое объяснение."
        }
    }
}

private struct OpenRouterChatRequest: Encodable {
    let model: String
    let messages: [OpenRouterChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenRouterChatMessage: Encodable {
    let role: String
    let content: OpenRouterMessageContent
}

private enum OpenRouterMessageContent: Encodable {
    case text(String)
    case parts([OpenRouterContentPart])

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(text):
            var container = encoder.singleValueContainer()
            try container.encode(text)
        case let .parts(parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }
}

private struct OpenRouterContentPart: Encodable {
    let type: String
    let text: String?
    let imageURL: OpenRouterImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    static func text(_ text: String) -> OpenRouterContentPart {
        OpenRouterContentPart(type: "text", text: text, imageURL: nil)
    }

    static func imageURL(_ url: String) -> OpenRouterContentPart {
        OpenRouterContentPart(type: "image_url", text: nil, imageURL: OpenRouterImageURL(url: url))
    }
}

private struct OpenRouterImageURL: Encodable {
    let url: String
}

private struct OpenRouterChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}
