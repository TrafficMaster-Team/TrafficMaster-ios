//
//  OpenRouterClient.swift
//  TrafficMaster
//

import Foundation
import UIKit

struct AITutorQuestionContext: Identifiable, Sendable {
    let id: String
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

    private let apiKey = "YOUR_API_KEY" // Вставьте сюда свой API ключ
    private let model = "google/gemini-2.5-flash-lite"
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
        var fullAnswer = ""
        try await streamTutorRequest(context: context, visibleMessages: visibleMessages) { chunk in
            fullAnswer += chunk
        }
        return fullAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func streamTutorRequest(
        context: AITutorQuestionContext,
        visibleMessages: [AITutorChatMessage],
        onChunk: @escaping (String) async -> Void
    ) async throws {
        var request = try makeRequest(context: context, visibleMessages: visibleMessages, stream: true)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw OpenRouterClientError.serverStatus(httpResponse.statusCode, "")
        }

        var didHitTokenLimit = false

        for try await line in bytes.lines {
            if Task.isCancelled { throw CancellationError() }
            guard let payload = ssePayload(from: line) else { continue }
            if payload == "[DONE]" { break }

            let data = Data(payload.utf8)
            let chunk = try decoder.decode(OpenRouterStreamChunk.self, from: data)
            if let apiError = chunk.error {
                throw OpenRouterClientError.apiError(apiError.message)
            }

            if let content = chunk.choices.first?.delta.content, !content.isEmpty {
                await onChunk(content)
            }

            if chunk.choices.contains(where: { $0.finishReason == "length" }) {
                didHitTokenLimit = true
            }
        }

        if didHitTokenLimit {
            await onChunk("\n\n_Ответ оборвался по лимиту. Спросите уточнение, и я продолжу._")
        }
    }

    private func makeRequest(
        context: AITutorQuestionContext,
        visibleMessages: [AITutorChatMessage],
        stream: Bool
    ) throws -> URLRequest {
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
            temperature: 0.2,
            stream: stream
        )
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private func ssePayload(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        return line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
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

        for message in visibleMessages where !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
        Ты AI-репетитор TrafficMaster для подготовки к экзамену по ПДД Республики Беларусь.
        Отвечай по-русски, коротко и по делу; обычно хватает 3-5 коротких пунктов.
        Не используй markdown-заголовки ## и длинные разделы. Можно использовать короткие списки, переносы строк и **жирный** текст.
        Если пользователь ошибся: 1 коротко почему неверно, 2 почему правильный ответ верный, 3 тема или пункт ПДД РБ.
        Если пользователь ответил правильно: закрепи правило и назови тему или пункт ПДД РБ.
        Указывай точные пункты ПДД РБ только когда уверен; иначе пиши "по смыслу правила" и тему.
        Не давай юридических обещаний; это учебное объяснение для экзамена.
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
        Разбери вопрос по ПДД РБ коротко, но без потери важного смысла.

        Раздел: \(context.sectionTitle ?? "не указан")
        Глава: \(context.chapterTitle ?? "не указана")

        Вопрос:
        \(context.questionText)

        Варианты ответа:
        \(answersText)

        Ответ пользователя: \(context.userAnswer)
        Правильный ответ: \(context.correctAnswer)
        Результат: \(resultText)
        Локальное пояснение: \(explanationText)

        Формат ответа: по возможности 3-5 коротких bullet-пунктов. Без вступления и без длинных цитат.
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
    case apiError(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Не задан ключ OpenRouter."
        case .invalidResponse:
            "OpenRouter вернул некорректный ответ."
        case let .serverStatus(statusCode, body):
            "OpenRouter вернул статус \(statusCode). \(body)"
        case let .apiError(message):
            "OpenRouter остановил поток: \(message)"
        case .emptyResponse:
            "OpenRouter вернул пустое объяснение."
        }
    }
}

private struct OpenRouterChatRequest: Encodable {
    let model: String
    let messages: [OpenRouterChatMessage]
    let temperature: Double
    let stream: Bool
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

private struct OpenRouterStreamChunk: Decodable {
    let choices: [OpenRouterStreamChoice]
    let error: OpenRouterAPIError?
}

private struct OpenRouterStreamChoice: Decodable {
    let delta: OpenRouterStreamDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

private struct OpenRouterStreamDelta: Decodable {
    let content: String?
}

private struct OpenRouterAPIError: Decodable {
    let message: String
}
