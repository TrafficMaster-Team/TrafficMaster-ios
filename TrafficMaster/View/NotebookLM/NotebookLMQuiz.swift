import Foundation

struct NotebookLMQuiz: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let title: String?
    let topic: String?
    let questions: [NotebookLMQuestion]
    
    enum CodingKeys: String, CodingKey {
        case title
        case topic
        case questions
    }
}

struct NotebookLMQuestion: Codable, Hashable {
    let question: String
    let answerOptions: [NotebookLMAnswerOption]
    let hint: String?
    
    enum CodingKeys: String, CodingKey {
        case question
        case answerOptions
        case hint
    }
}

struct NotebookLMAnswerOption: Codable, Hashable {
    let text: String
    let isCorrect: Bool
    let rationale: String?
}
