import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode, let body):
            return "HTTP \(statusCode): \(body)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    var config: APIConfig
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(config: APIConfig = .local, session: URLSession = .shared) {
        self.config = config
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func fetchReviewQueue(deckID: UUID, limit: Int = 80) async throws -> APIReviewQueueResponse {
        var components = URLComponents(url: config.baseURL.appendingPathComponent("v1/decks/\(deckID.uuidString)/review-queue"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components?.url else { throw APIClientError.invalidResponse }

        let request = makeRequest(url: url, method: .get)
        return try await send(request, decodeAs: APIReviewQueueResponse.self)
    }

    func signUp(payload: APISignUpRequest) async throws -> APISignUpResponse {
        let url = config.baseURL.appendingPathComponent("v1/auth/signup")
        var request = makeRequest(url: url, method: .post)
        request.httpBody = try encoder.encode(payload)

        return try await send(request, decodeAs: APISignUpResponse.self)
    }

    @discardableResult
    func logIn(payload: APILoginRequest) async throws -> HTTPURLResponse {
        let url = config.baseURL.appendingPathComponent("v1/auth/login")
        var request = makeRequest(url: url, method: .post)
        request.httpBody = try encoder.encode(payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIClientError.httpError(statusCode: httpResponse.statusCode, body: "Login failed")
        }

        return httpResponse
    }

    func reviewCard(cardID: UUID, payload: APIReviewCardRequest) async throws -> APIReviewCardResponse {
        let url = config.baseURL.appendingPathComponent("v1/cards/\(cardID.uuidString)/review")
        var request = makeRequest(url: url, method: .post)
        request.httpBody = try encoder.encode(payload)

        return try await send(request, decodeAs: APIReviewCardResponse.self)
    }

    func pushSyncEvents(_ payload: APISyncPushRequest) async throws -> APISyncPushResponse {
        let url = config.baseURL.appendingPathComponent("v1/sync/push")
        var request = makeRequest(url: url, method: .post)
        request.httpBody = try encoder.encode(payload)

        return try await send(request, decodeAs: APISyncPushResponse.self)
    }

    private func makeRequest(url: URL, method: HTTPMethod) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: config.requestTimeout)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, decodeAs type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw APIClientError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        return try decoder.decode(type, from: data)
    }
}
