import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct APIConfig {
    var baseURL: URL
    var requestTimeout: TimeInterval = 30

    static let local = APIConfig(baseURL: URL(string: "http://localhost:8000")!)
}

struct APIDeck: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String?
}

struct APIReviewQueueResponse: Codable, Sendable {
    let items: [APIReviewQueueItem]
}

struct APIReviewQueueItem: Codable, Sendable {
    let cardID: UUID
    let question: String
    let answer: String
    let imagePath: String?
    let tags: [String]
    let state: String?
    let interval: Int?
    let repetitions: Int?
    let nextReviewAt: Date?
    let reason: String
    let answerOptions: [APIReviewOption]

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id"
        case question
        case answer
        case imagePath = "image_path"
        case tags
        case state
        case interval
        case repetitions
        case nextReviewAt = "next_review_at"
        case reason
        case answerOptions = "answer_options"
    }
}

struct APIReviewOption: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let order: Int?
}

struct APIReviewCardRequest: Codable, Sendable {
    let rating: Int
    let clientEventID: UUID?
    let selectedOptionID: UUID?
    let answeredAt: Date?
    let timeSpentMs: Int?

    enum CodingKeys: String, CodingKey {
        case rating
        case clientEventID = "client_event_id"
        case selectedOptionID = "selected_option_id"
        case answeredAt = "answered_at"
        case timeSpentMs = "time_spent_ms"
    }
}

struct APIReviewCardResponse: Codable, Sendable {
    let cardProgressID: UUID
    let reviewLogID: UUID
    let state: String
    let interval: Int
    let nextReviewAt: Date?

    enum CodingKeys: String, CodingKey {
        case cardProgressID = "card_progress_id"
        case reviewLogID = "review_log_id"
        case state
        case interval
        case nextReviewAt = "next_review_at"
    }
}

struct APISyncReviewEvent: Codable, Sendable {
    let clientEventID: UUID
    let type: String
    let cardID: UUID
    let selectedOptionID: UUID?
    let rating: Int
    let answeredAt: Date
    let timeSpentMs: Int
    let deviceID: UUID

    enum CodingKeys: String, CodingKey {
        case clientEventID = "client_event_id"
        case type
        case cardID = "card_id"
        case selectedOptionID = "selected_option_id"
        case rating
        case answeredAt = "answered_at"
        case timeSpentMs = "time_spent_ms"
        case deviceID = "device_id"
    }
}

struct APISyncPushRequest: Codable, Sendable {
    let deviceID: UUID
    let baseCursor: String?
    let events: [APISyncReviewEvent]

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case baseCursor = "base_cursor"
        case events
    }
}

struct APISyncPushResponse: Codable, Sendable {
    let acceptedEventIDs: [UUID]
    let rejectedEvents: [APIRejectedEvent]
    let nextCursor: String

    enum CodingKeys: String, CodingKey {
        case acceptedEventIDs = "accepted_event_ids"
        case rejectedEvents = "rejected_events"
        case nextCursor = "next_cursor"
    }
}

struct APIRejectedEvent: Codable, Sendable {
    let clientEventID: UUID
    let reason: String

    enum CodingKeys: String, CodingKey {
        case clientEventID = "client_event_id"
        case reason
    }
}
