import Foundation

public struct PushoverCredentials: Equatable, Sendable {
    public let appToken: String
    public let userKey: String

    public init(appToken: String, userKey: String) {
        self.appToken = appToken
        self.userKey = userKey
    }
}

public struct PushoverMessage: Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public struct PushoverProviderReceipt: Equatable, Sendable {
    public let requestID: String?

    public init(requestID: String?) {
        self.requestID = requestID
    }
}

public enum PushoverTransportError: Error, Equatable, Sendable {
    case credentialsMissing
    case transportUnavailable
    case invalidProviderResponse
    case providerRejected

    var sanitizedCode: String {
        switch self {
        case .credentialsMissing: "credentials_missing"
        case .transportUnavailable: "transport_unavailable"
        case .invalidProviderResponse: "invalid_provider_response"
        case .providerRejected: "provider_rejected"
        }
    }
}

public protocol PushoverTransport: Sendable {
    func send(
        _ message: PushoverMessage,
        credentials: PushoverCredentials
    ) async throws -> PushoverProviderReceipt
}

public struct PushoverClient: PushoverTransport, Sendable {
    public static let endpoint = URL(string: "https://api.pushover.net/1/messages.json")!
    static let defaultSessionDelegate = PushoverRedirectRejectingDelegate()

    private let session: URLSession

    public init(session: URLSession? = nil) {
        self.session = session ?? URLSession(
            configuration: .ephemeral,
            delegate: Self.defaultSessionDelegate,
            delegateQueue: nil
        )
    }

    public func send(
        _ message: PushoverMessage,
        credentials: PushoverCredentials
    ) async throws -> PushoverProviderReceipt {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(message: message, credentials: credentials)
        request.timeoutInterval = 20
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PushoverTransportError.transportUnavailable
        }
        guard let http = response as? HTTPURLResponse, data.count <= 65_536 else {
            throw PushoverTransportError.invalidProviderResponse
        }
        guard http.statusCode == 200 else {
            throw PushoverTransportError.providerRejected
        }
        struct ProviderResponse: Decodable {
            let status: Int
            let request: String?
        }
        guard let decoded = try? JSONDecoder().decode(ProviderResponse.self, from: data),
              decoded.status == 1,
              decoded.request.map({ !$0.isEmpty && $0.utf8.count <= 256 }) != false else {
            throw PushoverTransportError.invalidProviderResponse
        }
        return PushoverProviderReceipt(requestID: decoded.request)
    }

    private static func formBody(
        message: PushoverMessage,
        credentials: PushoverCredentials
    ) -> Data {
        let values = [
            ("token", credentials.appToken),
            ("user", credentials.userKey),
            ("title", message.title),
            ("message", message.message),
        ]
        let encoded = values.map { key, value in
            "\(formEncode(key))=\(formEncode(value))"
        }.joined(separator: "&")
        return Data(encoded.utf8)
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

final class PushoverRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
