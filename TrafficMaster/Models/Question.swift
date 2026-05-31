import Foundation

struct AnswerOption: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let position: Int
    let isCorrect: Bool
}

struct Question: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let explanation: String?
    let imageName: String?
    let sectionTitle: String?
    let chapterTitle: String?
    let correctOptionID: UUID
    let options: [AnswerOption]
}

enum FSRSStatus: String, Codable, Sendable {
    case new
    case learning
    case review
    case relearning
}

struct FSRSState: Equatable, Sendable {
    var status: FSRSStatus
    var dueAt: Date
    var stability: Double
    var difficulty: Double
    var repetitions: Int
    var lapses: Int
    var lastReviewAt: Date?

    static let fresh = FSRSState(
        status: .new,
        dueAt: .distantPast,
        stability: 0.0,
        difficulty: 5.0,
        repetitions: 0,
        lapses: 0,
        lastReviewAt: nil
    )
}

enum ReviewRating: Int, Codable, CaseIterable, Sendable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

struct QuestionCard: Identifiable, Equatable, Sendable {
    let question: Question
    var state: FSRSState

    var id: UUID { question.id }
}

struct StudySettings: Equatable, Sendable {
    var newCardsPerDay: Int
    var maxReviewsPerDay: Int
    var showEasyButton: Bool
    var aiExplanationsEnabled: Bool
    var openRouterModel: String

    static let `default` = StudySettings(
        newCardsPerDay: 34,
        maxReviewsPerDay: 200,
        showEasyButton: false,
        aiExplanationsEnabled: false,
        openRouterModel: "deepseek/deepseek-chat-v3-0324"
    )
}
