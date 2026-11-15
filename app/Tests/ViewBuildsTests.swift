import XCTest
@testable import OpenspotCore

final class ViewBuildsTests: XCTestCase {
    private var folder: URL!
    private let view = "import SwiftUI\n\nstruct SpotView: View {\n    let spot: SpotInput\n    var body: some View { Text(\"cups\") }\n}\n"

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-view-builds-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func builds(selector: String = "exit 0", compiler: String) throws -> ViewBuilds {
        let place = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        try "#!/bin/sh\necho x >> '\(folder.appendingPathComponent("asks").path)'\n\(selector)\n".writeScript(to: place.appendingPathComponent("xcode-select"))
        try "#!/bin/sh\necho x >> '\(folder.appendingPathComponent("compiles").path)'\n\(compiler)\n".writeScript(to: place.appendingPathComponent("swiftc"))
        return ViewBuilds(library: ViewLibrary(cache: folder.appendingPathComponent("cache"), tools: place))
    }

    private let writes = "while [ $# -gt 0 ]; do [ \"$1\" = -o ] && printf built > \"$2\"; shift; done"
    private let breaks = "echo 'cups.swift:5:1: error: expected a view' >&2; exit 1"

    private func count(_ name: String) -> Int {
        ((try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)) ?? "").split(separator: "\n").count
    }

    private func source(_ text: String? = nil) throws -> URL {
        let url = folder.appendingPathComponent("cups.swift")
        try Data((text ?? view).utf8).write(to: url)
        return url
    }

    private func fault(of builds: ViewBuilds, _ source: URL) async -> String? {
        do {
            _ = try await builds.library(of: source)
            return nil
        } catch {
            return (error as? SpotError)?.reason
        }
    }

    func testAViewThatDoesNotCompileStartsNoProcessWhenItIsAskedForAgain() async throws {
        let builds = try builds(compiler: breaks)
        let source = try source()

        let first = await fault(of: builds, source)
        let second = await fault(of: builds, source)

        XCTAssertEqual(first, "This view does not compile. cups.swift:5:1: error: expected a view")
        XCTAssertEqual(second, first)
        XCTAssertEqual(count("asks"), 1)
        XCTAssertEqual(count("compiles"), 1)
    }

    func testABrokenViewIsBuiltAgainOnceItsSourceChanges() async throws {
        let builds = try builds(compiler: breaks)
        _ = await fault(of: builds, try source())

        _ = await fault(of: builds, try source(view + "\n"))

        XCTAssertEqual(count("compiles"), 2)
    }

    func testTwoAsksForOneViewAtOnceShareOneBuild() async throws {
        let gate = folder.appendingPathComponent("gate").path
        let builds = try builds(compiler: "while [ ! -e '\(gate)' ]; do /bin/sleep 0.01; done\n\(writes)")
        let source = try source()

        async let first = builds.library(of: source)
        async let second = builds.library(of: source)
        try await wait("the first build to start") { self.count("compiles") >= 1 }
        FileManager.default.createFile(atPath: gate, contents: nil)
        let libraries = try await [first, second]

        XCTAssertEqual(libraries[0], libraries[1])
        XCTAssertEqual(count("compiles"), 1)
    }

    func testAFailureThatDoesNotNameTheSourceIsBuiltAgain() async throws {
        let builds = try builds(compiler: "echo 'error: you have not agreed to the Xcode license' >&2; exit 1")
        let source = try source()

        _ = await fault(of: builds, source)
        _ = await fault(of: builds, source)

        XCTAssertEqual(count("compiles"), 2)
    }

    func testAMacWithNoDeveloperToolsStartsNoProcessWhenAViewIsAskedForAgain() async throws {
        let builds = try builds(selector: "exit 1", compiler: writes)
        let source = try source()

        let first = await fault(of: builds, source)
        let second = await fault(of: builds, source)
        let other = await fault(of: builds, try self.source(view + "\n"))

        XCTAssertEqual(first, "To draw a view, install the Command Line Tools: xcode-select --install")
        XCTAssertEqual(second, first)
        XCTAssertEqual(other, first)
        XCTAssertEqual(count("asks"), 1)
    }

    func testAViewThatWasBuiltBeforeIsFoundOnAMacWithNoDeveloperTools() async throws {
        let source = try source()
        let built = try await builds(compiler: writes).library(of: source)
        let builds = try builds(selector: "exit 1", compiler: writes)
        _ = await fault(of: builds, try self.source(view + "\n"))

        let found = try await builds.library(of: try self.source())

        XCTAssertEqual(found, built)
    }

    func testABuiltViewSaysWhetherItsSourceReadsIsShown() async throws {
        let builds = try builds(compiler: writes)

        let plain = try await builds.built(of: try source())
        let reading = try await builds.built(of: try source(view.replacingOccurrences(of: "Text(\"cups\")", with: "Text(spot.isShown ? \"cups\" : \"\")")))

        XCTAssertFalse(plain.readsShown)
        XCTAssertTrue(reading.readsShown)
        XCTAssertNotEqual(plain.library, reading.library)
    }

    func testOnlyTheLatestFaultsAreKept() async throws {
        let builds = try builds(compiler: breaks)
        for index in 0...ViewBuilds.faultLimit {
            _ = await fault(of: builds, try source(view + String(repeating: "\n", count: index)))
        }
        let kept = await builds.faultCount
        XCTAssertEqual(kept, ViewBuilds.faultLimit)

        _ = await fault(of: builds, try source(view))

        XCTAssertEqual(count("compiles"), ViewBuilds.faultLimit + 2)
    }
}
