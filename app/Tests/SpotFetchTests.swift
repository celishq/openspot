import XCTest
@testable import OpenspotCore

@MainActor
final class SpotFetchTests: SpotRunsCase {
    override func setUp() async throws {
        try await super.setUp()
        runs.fetch = Fetch(configuration: FakeWeb.configuration, wait: 30)
        runs.api = CommandAPI(mac: Mac(), places: .test(["OPENSPOT_CONFIG": folder.appendingPathComponent("config").path]), runs: runs)
    }

    private func fetching(uses: String = "uses = ['network']\n", _ fetch: String) throws -> SpotRun {
        let url = folder.spotFile("script", extension: "js")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        export default {
          async search({ text }, env) {
            try {
              \(fetch)
            } catch (error) {
              return `item=${text}\\ntitle=${error.cause}\\ndetail=${error.message}\\n`
            }
          },
        }

        """.write(to: url, atomically: true, encoding: .utf8)
        try "\(uses)[on]\nsearch = '^[a-z]'\n".write(to: url.deletingLastPathComponent().appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
        return try sheet()
    }

    private func answer(_ url: String, status: Int = 200, body: String, headers: [String: String] = [:]) {
        FakeWeb.answers.withLock { $0[url] = .init(status: status, body: Data(body.utf8), headers: headers) }
    }

    private func titled(_ sheet: SpotRun, _ text: String) async throws -> String? {
        sheet.answer(text)
        try await wait("the answer to \(text)") { sheet.answers.map(\.run) == [text] }
        return sheet.answers.first?.title
    }

    func testAFetchGivesTheStatusTheHeadersAndTheBody() async throws {
        answer("https://fetch.test/one", status: 201, body: "hello", headers: ["Content-Type": "text/plain"])
        let sheet = try fetching("""
        const answer = await env.fetch(`https://fetch.test/${text}`)
        return `item=${text}\\ntitle=${answer.status} ${answer.ok} ${answer.headers.get("content-type")} ${await answer.text()}\\n`
        """)

        let title = try await titled(sheet, "one")

        XCTAssertEqual(title, "201 true text/plain hello")
    }

    func testJSONReadsTheBody() async throws {
        answer("https://fetch.test/json", body: #"{"usd":{"eur":0.9}}"#)
        let sheet = try fetching("""
        const rates = await (await env.fetch("https://fetch.test/json")).json()
        return `item=${text}\\ntitle=${rates.usd.eur}\\n`
        """)

        let title = try await titled(sheet, "json")

        XCTAssertEqual(title, "0.9")
    }

    func testTheMethodAndTheHeadersReachTheServer() async throws {
        answer("https://fetch.test/post", body: "ok")
        let sheet = try fetching("""
        const answer = await env.fetch("https://fetch.test/post", { method: "POST", headers: { "X-Key": "k1" }, body: "sent" })
        return `item=${text}\\ntitle=${await answer.text()}\\n`
        """)

        let title = try await titled(sheet, "post")

        XCTAssertEqual(title, "ok")
        let asked = FakeWeb.asked.withLock { $0.last { $0.url?.absoluteString == "https://fetch.test/post" } }
        XCTAssertEqual(asked?.httpMethod, "POST")
        XCTAssertEqual(asked?.value(forHTTPHeaderField: "X-Key"), "k1")
    }

    func testAnAnswerOverTwoMegabytesFailsAsLimit() async throws {
        answer("https://fetch.test/big", body: String(repeating: "a", count: Fetch.byteLimit + 1))
        let sheet = try fetching("""
        await env.fetch("https://fetch.test/big")
        return `item=${text}\\ntitle=read\\n`
        """)

        let title = try await titled(sheet, "big")

        XCTAssertEqual(title, "limit")
    }

    func testAnAnswerThatNeverComesFailsAsTimeoutAfterTheWait() async throws {
        runs.fetch = Fetch(configuration: FakeWeb.configuration, wait: 0.3)
        let sheet = try fetching("""
        await env.fetch("https://fetch.test/never")
        return `item=${text}\\ntitle=read\\n`
        """)

        let title = try await titled(sheet, "never")

        XCTAssertEqual(title, "timeout")
    }

    func testAFetchOfASpotWithoutTheNetworkUseIsRefused() async throws {
        answer("https://fetch.test/careful", body: "ok")
        let sheet = try fetching(uses: "", """
        await env.fetch("https://fetch.test/careful")
        return `item=${text}\\ntitle=read\\n`
        """)

        let title = try await titled(sheet, "careful")

        XCTAssertEqual(title, "refused")
    }

    func testAnAddressThatIsNotTheWebFails() async throws {
        let sheet = try fetching("""
        await env.fetch("file:///etc/hosts")
        return `item=${text}\\ntitle=read\\n`
        """)

        let title = try await titled(sheet, "file")

        XCTAssertEqual(title, "unavailable")
    }
}
