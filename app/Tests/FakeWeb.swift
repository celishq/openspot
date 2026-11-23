import Synchronization
import XCTest
@testable import OpenspotCore

final class FakeWeb: URLProtocol, @unchecked Sendable {
    struct Answer: Sendable {
        let status: Int
        let body: Data
        let headers: [String: String]
    }

    static let answers = Mutex<[String: Answer]>([:])
    static let asked = Mutex<[URLRequest]>([])

    static var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FakeWeb.self]
        return configuration
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.asked.withLock { $0.append(request) }
        guard let url = request.url, let answer = Self.answers.withLock({ $0[url.absoluteString] }) else { return }
        let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: answer.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
