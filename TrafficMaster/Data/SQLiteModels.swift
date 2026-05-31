import Foundation

struct QuestionImportDTO: Codable {
    let hierarchy: String
    let question: String
    let image: String?
    let options: [String]
    let correctIndex: Int
    let correctText: String
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case hierarchy, question, image, options, explanation
        case correctIndex = "correct_index"
        case correctText = "correct_text"
    }
}

struct LocalRuleChunk: Equatable, Sendable {
    let source: String
    let title: String
    let text: String
}

struct ExportQuestionDTO: Codable {
    struct ExportAnswerDTO: Codable {
        let answerID: String
        let text: String
        let isCorrect: Bool

        enum CodingKeys: String, CodingKey {
            case answerID = "answer_id"
            case text
            case isCorrect = "is_correct"
        }
    }

    let questionID: String
    let chapterURL: String
    let questionText: String
    let answers: [ExportAnswerDTO]
    let correctAnswerIDs: [String]
    let explanation: String?
    let rulesRef: String?
    let mediaFiles: [String]

    enum CodingKeys: String, CodingKey {
        case questionID = "question_id"
        case chapterURL = "chapter_url"
        case questionText = "question_text"
        case answers
        case correctAnswerIDs = "correct_answer_ids"
        case explanation
        case rulesRef = "rules_ref"
        case mediaFiles = "media_files"
    }
}

enum SoloSchema {
    static let version = 1
}
