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
                let correctIndex = item.answerOptions.firstIndex {
                    $0.text.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(normalizedAnswer) == .orderedSame
                } ?? 0
                
                let question = Question(
                    id: item.cardID,
                    text: item.question,
                    options: item.answerOptions.map(\.text),
                    answerOptions: item.answerOptions.enumerated().map { idx, option in
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
                    sectionTitle: "Синхронизировано",
                    chapterTitle: item.reason,
                    repetitions: item.repetitions ?? 0,
                    interval: item.interval ?? 1,
                    nextReviewDate: item.nextReviewAt ?? Date()
                )
                try database.saveQuestion(question)
            }
        }
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
}
