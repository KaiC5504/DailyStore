import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPResponse: Sendable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    public var isSuccess: Bool { (200..<300).contains(status) }
}

public protocol HTTPClient: Sendable {
    /// Must return redirects as-is instead of following them: the reauth token lives in the
    /// `Location` fragment, which is lost once a redirect is followed.
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

public final class URLSessionHTTPClient: NSObject, HTTPClient, URLSessionTaskDelegate, @unchecked Sendable {
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        // Cookies are managed by RiotCookies; a shared jar would leak stale ones into requests.
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    public override init() { super.init() }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RiotError.unexpected(step: request.url?.host ?? "request")
        }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String { headers[key] = value }
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: data)
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
