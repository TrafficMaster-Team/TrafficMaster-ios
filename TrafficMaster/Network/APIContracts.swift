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

struct APIReviewQueueResponse: Decodable, Sendable {
    let items: [APIReviewQueueItem]

    init(items: [APIReviewQueueItem]) {
        self.items = items
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let items = try? container.decode([APIReviewQueueItem].self) {
            self.items = items
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decode([APIReviewQueueItem].self, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }
}

struct APIReviewQueueItem: Decodable, Sendable {
    let cardID: UUID
    let question: String
    let answer: String
    let imagePath: String?
    let tags: [String]
    let state: SM2CardState?
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardID = try container.decode(UUID.self, forKey: .cardID)
        question = try container.decode(String.self, forKey: .question)
        answer = try container.decode(String.self, forKey: .answer)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        state = try container.decodeIfPresent(SM2CardState.self, forKey: .state)
        interval = try container.decodeIfPresent(Int.self, forKey: .interval)
        repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions)
        nextReviewAt = try container.decodeIfPresent(Date.self, forKey: .nextReviewAt)
        reason = try container.decode(String.self, forKey: .reason)
        answerOptions = try container.decodeIfPresent([APIReviewOption].self, forKey: .answerOptions) ?? []
    }
}

struct APIReviewOption: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let order: Int?
}

struct APISignUpRequest: Codable, Sendable {
    let email: String
    let name: String
    let password: String
}

struct APISignUpResponse: Codable, Sendable {
    let id: UUID
}

struct APILoginRequest: Codable, Sendable {
    let email: String
    let password: String
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
    let state: SM2CardState
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
