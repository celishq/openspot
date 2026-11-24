import Foundation

public struct Fetch: Sendable {
    public static let byteLimit = 2 << 20
    private static let chunk = 64 << 10
    public static let use = SpotUseCall(name: "fetch", rule: CallRule(use: .network, used: "reached the network"))

    nonisolated(unsafe) let configuration: URLSessionConfiguration
    let wait: TimeInterval

    public init(configuration: URLSessionConfiguration = .ephemeral, wait: TimeInterval = 30) {
        self.configuration = configuration
        self.wait = wait
    }

    public func session() -> URLSession {
        URLSession(configuration: configuration)
    }

    public func answer(_ url: String, method: String, headers: [String: String], body: String?, in session: URLSession) async -> FetchAnswer {
        guard let address = URL(string: url), ["http", "https"].contains(address.scheme?.lowercased() ?? "") else {
            return .failed(.unavailable, "Openspot fetches only an http or https address: \(url).")
        }
        var request = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: wait)
        request.httpMethod = method.uppercased()
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = body.map { Data($0.utf8) }
        let sent = request
        return await withTaskGroup(of: FetchAnswer.self) { group in
            group.addTask { await read(sent, in: session) }
            group.addTask {
                try? await Task.sleep(for: .seconds(wait))
                return .failed(.timeout, "\(address.host() ?? url) did not answer in \(Int(wait)) seconds.")
            }
            let first = await group.next() ?? .failed(.unavailable, "")
            group.cancelAll()
            return first
        }
    }

    private func read(_ request: URLRequest, in session: URLSession) async -> FetchAnswer {
        let host = request.url?.host() ?? ""
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else { return .failed(.unavailable, "\(host) did not answer over http.") }
            guard response.expectedContentLength <= Self.byteLimit else { return Self.overLimit(host) }
            var body = Data()
            var chunk: [UInt8] = []
            chunk.reserveCapacity(Self.chunk)
            for try await byte in bytes {
                chunk.append(byte)
                guard chunk.count == Self.chunk else { continue }
                autoreleasepool { body.append(contentsOf: chunk) }
                chunk.removeAll(keepingCapacity: true)
                if body.count > Self.byteLimit { return Self.overLimit(host) }
            }
            body.append(contentsOf: chunk)
            if body.count > Self.byteLimit { return Self.overLimit(host) }
            let headers = response.allHeaderFields.reduce(into: [String: String]()) { kept, field in
                kept["\(field.key)".lowercased()] = "\(field.value)"
            }
            return .answered(status: response.statusCode, url: response.url?.absoluteString ?? "", headers: headers, body: String(decoding: body, as: UTF8.self))
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff].contains(error.code) {
            return .failed(.offline, "The Mac is offline, so Openspot cannot reach \(host).")
        } catch let error as URLError where error.code == .timedOut {
            return .failed(.timeout, "\(host) did not answer in \(Int(wait)) seconds.")
        } catch {
            return .failed(.unavailable, "\(host) cannot be reached: \(error.localizedDescription)")
        }
    }

    private static func overLimit(_ host: String) -> FetchAnswer {
        .failed(.limit, "The answer of \(host) is over \(byteLimit >> 20) MB, the most a fetch takes.")
    }
}
