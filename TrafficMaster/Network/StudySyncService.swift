import Foundation

final class StudySyncService {
    private let apiClient: APIClient
    private let database: DatabaseService

    init(apiClient: APIClient = .shared, database: DatabaseService = .shared) {
        self.apiClient = apiClient
        self.database = database
    }

    func refreshReviewQueue(deckID: UUID, limit: Int = 80) async throws {
        let response = try await apiClient.fetchReviewQueue(deckID: deckID, limit: limit)

        try database.executeTransaction {
            for item in response.items {
                let normalizedAnswer = item.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                let apiOptions = item.answerOptions.isEmpty
                    ? [APIReviewOption(id: UUID(), text: item.answer, order: 0)]
                    : item.answerOptions
                let correctIndex = apiOptions.firstIndex {
                    $0.text.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(normalizedAnswer) == .orderedSame
                } ?? 0

                let question = Question(
                    id: item.cardID,
                    text: item.question,
                    options: apiOptions.map(\.text),
                    answerOptions: apiOptions.enumerated().map { idx, option in
                        AnswerOption(
                            id: option.id,
                            text: option.text,
                            isCorrect: idx == correctIndex,
                            order: option.order ?? idx
                        )
                    },
                    correctAnswerIndex: correctIndex,
                    explanation: item.answer,
                    imageName: item.imagePath?.split(separator: ".").dropLast().joined(separator: "."),
                    backendCardID: item.cardID,
                    backendDeckID: deckID,
                    sectionTitle: "Синхронизировано",
                    chapterTitle: item.reason,
                    sm2State: item.state ?? .new,
                    repetitions: item.repetitions ?? 0,
                    interval: item.interval ?? 1,
                    nextReviewDate: item.nextReviewAt ?? Date()
                )
                try database.saveQuestion(question)
            }
        }
    }

    func submitReview(question: Question, event: SyncReviewEvent) async throws {
        guard let backendCardID = question.backendCardID else { return }

        let payload = APIReviewCardRequest(
            rating: event.rating.rawValue,
            clientEventID: event.id,
            selectedOptionID: event.selectedOptionID,
            answeredAt: event.answeredAt,
            timeSpentMs: event.timeSpentMs
        )
        let response = try await apiClient.reviewCard(cardID: backendCardID, payload: payload)
        try applyReviewResponse(response, to: question)
        try database.markReviewEventsSynced(eventIDs: [event.id])
    }

    func refreshCardProgress(for question: Question) async throws {
        guard let backendCardID = question.backendCardID else { return }
        let progress = try await apiClient.fetchCardProgress(cardID: backendCardID)
        applyCardProgress(progress, to: question)
        try database.saveQuestion(question)
    }

    func pushPendingReviewEvents(deviceID: UUID, baseCursor: String? = nil) async throws -> APISyncPushResponse? {
        let pendingEvents = try database.fetchPendingReviewEvents(limit: 200)
        guard !pendingEvents.isEmpty else { return nil }

        let payload = APISyncPushRequest(
            deviceID: deviceID,
            baseCursor: baseCursor,
            events: pendingEvents.map {
                APISyncReviewEvent(
                    clientEventID: $0.id,
                    type: "card_reviewed",
                    cardID: $0.cardId,
                    selectedOptionID: $0.selectedOptionID,
                    rating: $0.rating.rawValue,
                    answeredAt: $0.answeredAt,
                    timeSpentMs: $0.timeSpentMs,
                    deviceID: deviceID
                )
            }
        )

        let response = try await apiClient.pushSyncEvents(payload)
        try database.markReviewEventsSynced(eventIDs: response.acceptedEventIDs)
        return response
    }

    private func applyReviewResponse(_ response: APIReviewCardResponse, to question: Question) throws {
        question.backendCardProgressID = response.cardProgressID
        question.sm2State = response.state
        question.easinessFactor = response.easeFactor
        question.interval = response.interval
        question.repetitions = response.repetitions
        question.nextReviewDate = response.nextReviewAt ?? Date()
        try database.saveQuestion(question)
    }

    private func applyCardProgress(_ progress: APICardProgress, to question: Question) {
        question.backendCardProgressID = progress.id
        question.sm2State = progress.state
        question.easinessFactor = progress.easeFactor
        question.interval = progress.interval
        question.repetitions = progress.repetitions
        question.nextReviewDate = progress.nextReviewAt ?? Date()
    }
}
