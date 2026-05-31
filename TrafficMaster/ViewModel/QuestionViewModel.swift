import Foundation
import Combine

@MainActor
final class QuestionViewModel: ObservableObject {
    @Published private(set) var settings: StudySettings = .default
    @Published private(set) var currentCard: QuestionCard?
    @Published private(set) var sessionQueue: [QuestionCard] = []
    @Published private(set) var totalInSession: Int = 0
    @Published private(set) var completedInSession: Int = 0

    @Published var selectedOptionID: UUID?
    @Published var revealedRating: ReviewRating?
    @Published var generatedExplanation: String?
    @Published var isLoadingExplanation = false

    private let database: DatabaseService
    private let scheduler: FSRSScheduler
    private let ragService: RAGExplanationService
    private var questionShownAt: Date?

    init(
        database: DatabaseService? = nil,
        scheduler: FSRSScheduler? = nil,
        ragService: RAGExplanationService? = nil
    ) {
        self.database = database ?? .shared
        self.scheduler = scheduler ?? FSRSScheduler()
        self.ragService = ragService ?? .shared
    }

    var isCompleted: Bool {
        currentCard == nil
    }

    var currentQuestion: Question? {
        currentCard?.question
    }

    var canUseEasy: Bool {
        settings.showEasyButton
    }

    var selectedOption: AnswerOption? {
        guard let id = selectedOptionID else { return nil }
        return currentCard?.question.options.first(where: { $0.id == id })
    }

    var isCorrectSelection: Bool {
        guard let card = currentCard, let selected = selectedOptionID else { return false }
        return card.question.correctOptionID == selected
    }

    func loadSession() {
        do {
            settings = try database.loadSettings()
            try database.importBundledQuestionsIfNeeded()
            let cards = try database.fetchSessionCards(
                newLimit: settings.newCardsPerDay,
                maxReviews: settings.maxReviewsPerDay
            )
            sessionQueue = cards
            totalInSession = cards.count
            completedInSession = 0
            moveNext()
        } catch {
            sessionQueue = []
            currentCard = nil
            generatedExplanation = "Ошибка загрузки: \(error.localizedDescription)"
        }
    }

    func selectOption(_ optionID: UUID) {
        guard revealedRating == nil else { return }
        selectedOptionID = optionID
        revealedRating = isCorrectSelection ? .good : .again

        if !isCorrectSelection {
            Task { await loadMistakeExplanation() }
        } else {
            generatedExplanation = nil
        }
    }

    func applyGuessed() {
        guard revealedRating == .good else { return }
        revealedRating = .hard
    }

    func confirmCurrentAnswer() {
        guard let card = currentCard,
              let selectedOptionID,
              let rating = revealedRating
        else { return }

        let now = Date()
        let elapsedMs = max(0, Int((now.timeIntervalSince(questionShownAt ?? now)) * 1000.0))
        let result = scheduler.review(state: card.state, rating: rating, now: now)

        do {
            try database.saveReview(questionID: card.question.id, chosenOptionID: selectedOptionID, result: result, elapsedMs: elapsedMs)
        } catch {
            generatedExplanation = "Ошибка сохранения: \(error.localizedDescription)"
        }

        if rating == .again {
            var repeated = card
            repeated.state = result.state
            let insertIndex = min(sessionQueue.count, 2)
            sessionQueue.insert(repeated, at: insertIndex)
        }

        completedInSession += 1
        moveNext()
    }

    func refreshSettings() {
        if let loaded = try? database.loadSettings() {
            settings = loaded
        }
    }

    private func moveNext() {
        if sessionQueue.isEmpty {
            currentCard = nil
            selectedOptionID = nil
            revealedRating = nil
            generatedExplanation = nil
            questionShownAt = nil
            return
        }

        currentCard = sessionQueue.removeFirst()
        selectedOptionID = nil
        revealedRating = nil
        generatedExplanation = nil
        isLoadingExplanation = false
        questionShownAt = Date()
    }

    private func loadMistakeExplanation() async {
        guard let question = currentCard?.question,
              let selected = selectedOption
        else { return }

        isLoadingExplanation = true
        let text = await ragService.explanationForMistake(
            question: question,
            chosenOption: selected,
            settings: settings,
            includeImageContext: question.imageName != nil
        )
        generatedExplanation = text
        isLoadingExplanation = false
    }
}
