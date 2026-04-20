import Foundation
import FirebaseAuth

// MARK: - Response Models (match backend Pydantic models in main.py)

struct AllocateNumberResponse: Codable {
    let alynna_number: String
    let already_allocated: Bool
}

struct LookupNumberResponse: Codable {
    let nickname: String
    let join_days: Int
    let sun_sign: String?
}

struct BondRequestCreatedResponse: Codable {
    let request_id: String
    let expires_at: String
}

struct BondAcceptedResponse: Codable {
    let bond_id: String
    let cooling_until: String
}

struct BondSummary: Codable, Identifiable {
    let bond_id: String
    let status: String                 // "cooling" | "active" | "severed"
    let partner_uid: String
    let partner_nickname: String
    let partner_alynna_number: String
    let partner_focus_today: String?
    let compatibility_today: Int?
    let created_at: String?
    let cooling_until: String?

    var id: String { bond_id }
    var isActive: Bool { status == "active" }
    var isCooling: Bool { status == "cooling" }
}

struct PendingRequestSummary: Codable, Identifiable {
    let request_id: String
    let direction: String              // "sent" | "received"
    let other_uid: String
    let other_nickname: String
    let other_alynna_number: String
    let created_at: String?
    let expires_at: String?

    var id: String { request_id }
    var isSent: Bool { direction == "sent" }
    var isReceived: Bool { direction == "received" }
}

struct BondsListResponse: Codable {
    let bonds: [BondSummary]
    let pending_sent: [PendingRequestSummary]
    let pending_received: [PendingRequestSummary]
}

struct CompatibilityResponse: Codable {
    let bond_id: String
    let date: String
    let compatibility: Int
    let permanent_base: Int
    let shared_intents: [String]
    let focus_a: String?
    let focus_b: String?
    let generated_at: String
}

// Placeholder for endpoints that return `{}`.
struct EmptyResponse: Codable {}

// MARK: - Error Type

enum AlynnaAPIError: Error, LocalizedError {
    case notAuthenticated
    case tokenFetchFailed(Error)
    case networkError(Error)
    case invalidURL
    case serverError(statusCode: Int, detail: String?)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in."
        case .tokenFetchFailed(let e):
            return "Could not refresh auth token: \(e.localizedDescription)"
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .invalidURL:
            return "Invalid request URL."
        case .serverError(let code, let detail):
            if let d = detail, !d.isEmpty { return d }
            return "Server returned \(code)."
        case .decodingError(let e):
            return "Response decoding failed: \(e.localizedDescription)"
        }
    }

    /// Convenience: for UI that wants to branch on HTTP status.
    var httpStatusCode: Int? {
        if case .serverError(let code, _) = self { return code }
        return nil
    }
}

// MARK: - Client

/// Thin wrapper around the Alynna Cloud Run API. Responsibilities:
/// 1. Inject a fresh Firebase ID token into every request
/// 2. Map HTTP errors to a typed Swift error
/// 3. Provide async/await call sites for every bonding endpoint
///
/// Usage:
///   let number = try await AlynnaAPI.shared.allocateNumber().alynna_number
final class AlynnaAPI {
    static let shared = AlynnaAPI()

    /// Override for staging / local dev via @AppStorage or env if needed.
    var baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.baseURL = URL(string: "https://aligna-api-16639733048.us-central1.run.app")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: Auth token

    /// Fetch the current user's Firebase ID token. Uses the cached token
    /// unless it is expired. Returns on the calling thread via Swift concurrency.
    private func currentIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AlynnaAPIError.notAuthenticated
        }
        do {
            return try await user.getIDToken()
        } catch {
            throw AlynnaAPIError.tokenFetchFailed(error)
        }
    }

    // MARK: Core request builders

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        httpBody: Data? = nil,
        authToken: String
    ) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw AlynnaAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        if let body = httpBody {
            req.httpBody = body
        }
        return req
    }

    private func executeAndDecode<T: Decodable>(
        _ req: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw AlynnaAPIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AlynnaAPIError.serverError(statusCode: -1, detail: "No HTTP response")
        }

        if !(200..<300).contains(http.statusCode) {
            // FastAPI error format: {"detail": "..."} or {"detail": [...]}
            let detail = Self.extractDetailString(from: data)
            throw AlynnaAPIError.serverError(statusCode: http.statusCode, detail: detail)
        }

        // EmptyResponse short-circuit — `{}` decodes cleanly but treat defensively.
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AlynnaAPIError.decodingError(error)
        }
    }

    /// Pull a human-readable `detail` string from a FastAPI error payload.
    /// Handles both `{"detail": "msg"}` and `{"detail": [{"msg": "..."}, ...]}`.
    private static func extractDetailString(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = obj["detail"]
        else { return nil }
        if let s = detail as? String { return s }
        if let arr = detail as? [[String: Any]] {
            return arr.compactMap { $0["msg"] as? String }.first
        }
        return nil
    }

    // MARK: Request helpers (body / no body overloads)

    /// No-body request.
    private func send<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        responseType: T.Type
    ) async throws -> T {
        let token = try await currentIDToken()
        let req = try makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            httpBody: nil,
            authToken: token
        )
        return try await executeAndDecode(req, responseType: responseType)
    }

    /// Request with JSON-encoded body.
    private func send<B: Encodable, T: Decodable>(
        path: String,
        method: String = "POST",
        body: B,
        queryItems: [URLQueryItem] = [],
        responseType: T.Type
    ) async throws -> T {
        let token = try await currentIDToken()
        let bodyData = try encoder.encode(body)
        let req = try makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            httpBody: bodyData,
            authToken: token
        )
        return try await executeAndDecode(req, responseType: responseType)
    }

    // MARK: - Public endpoints

    // --- User / number ---

    func allocateNumber() async throws -> AllocateNumberResponse {
        return try await send(
            path: "/users/allocate_number",
            method: "POST",
            responseType: AllocateNumberResponse.self
        )
    }

    func lookupByNumber(_ number: String) async throws -> LookupNumberResponse {
        let cleaned = number.filter(\.isNumber)
        return try await send(
            path: "/users/lookup_by_number",
            method: "GET",
            queryItems: [URLQueryItem(name: "number", value: cleaned)],
            responseType: LookupNumberResponse.self
        )
    }

    // --- Blocking ---

    func blockNumber(_ number: String) async throws {
        struct Body: Encodable { let number: String }
        _ = try await send(
            path: "/users/block_number",
            method: "POST",
            body: Body(number: number.filter(\.isNumber)),
            responseType: EmptyResponse.self
        )
    }

    func unblockNumber(_ number: String) async throws {
        struct Body: Encodable { let number: String }
        _ = try await send(
            path: "/users/unblock_number",
            method: "POST",
            body: Body(number: number.filter(\.isNumber)),
            responseType: EmptyResponse.self
        )
    }

    // --- Push notification token registration ---

    /// Register or refresh this device's FCM push token so the backend can
    /// send localized bond notifications. Call on token receipt / refresh.
    func registerFcmToken(_ fcmToken: String, languageCode: String? = nil) async throws {
        struct Body: Encodable {
            let fcm_token: String
            let language_code: String?
        }
        _ = try await send(
            path: "/users/register_fcm_token",
            method: "POST",
            body: Body(fcm_token: fcmToken, language_code: languageCode),
            responseType: EmptyResponse.self
        )
    }

    /// Clear this user's stored push token. Call on sign-out.
    func unregisterFcmToken() async throws {
        _ = try await send(
            path: "/users/unregister_fcm_token",
            method: "POST",
            responseType: EmptyResponse.self
        )
    }

    // --- Bond lifecycle ---

    func sendBondRequest(toNumber: String, idempotencyKey: String? = nil) async throws -> BondRequestCreatedResponse {
        struct Body: Encodable {
            let to_alynna_number: String
            let idempotency_key: String?
        }
        return try await send(
            path: "/bonds/request",
            method: "POST",
            body: Body(
                to_alynna_number: toNumber.filter(\.isNumber),
                idempotency_key: idempotencyKey
            ),
            responseType: BondRequestCreatedResponse.self
        )
    }

    func acceptBondRequest(_ requestId: String) async throws -> BondAcceptedResponse {
        return try await send(
            path: "/bonds/requests/\(requestId)/accept",
            method: "POST",
            responseType: BondAcceptedResponse.self
        )
    }

    func declineBondRequest(_ requestId: String) async throws {
        _ = try await send(
            path: "/bonds/requests/\(requestId)/decline",
            method: "POST",
            responseType: EmptyResponse.self
        )
    }

    func cancelCoolingBond(_ bondId: String) async throws {
        _ = try await send(
            path: "/bonds/\(bondId)/cancel",
            method: "POST",
            responseType: EmptyResponse.self
        )
    }

    func severBond(_ bondId: String, clearHistoryImmediately: Bool = false) async throws {
        struct Body: Encodable { let clear_history_immediately: Bool }
        _ = try await send(
            path: "/bonds/\(bondId)/sever",
            method: "POST",
            body: Body(clear_history_immediately: clearHistoryImmediately),
            responseType: EmptyResponse.self
        )
    }

    func myBonds() async throws -> BondsListResponse {
        return try await send(
            path: "/bonds/my",
            method: "GET",
            responseType: BondsListResponse.self
        )
    }

    func compatibility(bondId: String, date: String? = nil) async throws -> CompatibilityResponse {
        var items: [URLQueryItem] = []
        if let d = date, !d.isEmpty {
            items.append(URLQueryItem(name: "date", value: d))
        }
        return try await send(
            path: "/bonds/\(bondId)/compatibility",
            method: "GET",
            queryItems: items,
            responseType: CompatibilityResponse.self
        )
    }
}

// MARK: - Convenience: formatted Alynna number

extension String {
    /// Convert a raw 8-digit Alynna number to the user-facing `"3847 2916"` form.
    /// Returns the original string if it's not 8 digits.
    var alynnaNumberDisplay: String {
        let digits = self.filter(\.isNumber)
        guard digits.count == 8 else { return self }
        let mid = digits.index(digits.startIndex, offsetBy: 4)
        return "\(digits[..<mid]) \(digits[mid...])"
    }

    /// Masked form: `"3847 **16"` — shows first 4 and last 2 digits.
    var alynnaNumberMasked: String {
        let digits = self.filter(\.isNumber)
        guard digits.count == 8 else { return self }
        let first4 = digits.prefix(4)
        let last2 = digits.suffix(2)
        return "\(first4) **\(last2)"
    }
}
