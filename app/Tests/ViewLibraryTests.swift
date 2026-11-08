import XCTest
@testable import OpenspotCore

final class ViewLibraryTests: XCTestCase {
    private var folder: URL!
    private let view = "import SwiftUI\n\nstruct SpotView: View {\n    let spot: SpotInput\n    var body: some View { Text(spot[\"title\"] ?? \"–\") }\n}\n"

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-views-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var cache: URL {
        folder.appendingPathComponent("cache")
    }

    /// A folder of stand-ins for the build commands, with a compiler that counts its runs and writes `built`.
    private func tools(selector: String = "exit 0", compiler: String? = nil) throws -> ViewLibrary {
        let place = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        let builds = folder.appendingPathComponent("builds").path
        let compile = compiler ?? "echo x >> '\(builds)'; while [ $# -gt 0 ]; do [ \"$1\" = -o ] && printf built > \"$2\"; shift; done"
        try "#!/bin/sh\n\(selector)\n".writeScript(to: place.appendingPathComponent("xcode-select"))
        try "#!/bin/sh\n\(compile)\n".writeScript(to: place.appendingPathComponent("swiftc"))
        return ViewLibrary(cache: cache, tools: place)
    }

    private var builds: Int {
        ((try? String(contentsOf: folder.appendingPathComponent("builds"), encoding: .utf8)) ?? "").split(separator: "\n").count
    }

    private func source(_ name: String = "cups.swift", _ text: String? = nil) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data((text ?? view).utf8).write(to: url)
        return url
    }

    func testAViewBuildsIntoALibraryWithItsEntry() async throws {
        let library = try await ViewLibrary(cache: cache).library(of: try source())

        let handle = try XCTUnwrap(dlopen(library.path, RTLD_NOW | RTLD_LOCAL), String(cString: dlerror()))
        XCTAssertNotNil(dlsym(handle, ViewLibrary.entry))
    }

    func testAnUnchangedViewIsBuiltOnce() async throws {
        let views = try tools()
        let file = try source()

        let first = try await views.library(of: file)
        let second = try await views.library(of: file)

        XCTAssertEqual(first, second)
        XCTAssertEqual(builds, 1)
        XCTAssertEqual(try Data(contentsOf: first), Data("built".utf8))
    }

    func testAChangedViewIsBuiltAgainUnderANewName() async throws {
        let views = try tools()
        let file = try source()
        let first = try await views.library(of: file)

        _ = try source("cups.swift", view + "\n")
        let second = try await views.library(of: file)

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(builds, 2)
    }

    func testAViewThatDoesNotCompileShowsItsFirstError() async throws {
        let views = try tools(compiler: "printf '/tmp/a/cups.swift:5:9: error: cannot find x in scope\\n    x\\n    ^\\n' >&2; exit 1")

        do {
            _ = try await views.library(of: try source())
            XCTFail("It must not build.")
        } catch {
            XCTAssertEqual((error as? PluginError)?.reason, "This view does not compile. cups.swift:5:9: error: cannot find x in scope")
        }
    }

    func testAMacWithNoToolsSaysHowToGetThem() async throws {
        let views = try tools(selector: "exit 2")

        do {
            _ = try await views.library(of: try source())
            XCTFail("It must not build.")
        } catch {
            XCTAssertEqual((error as? PluginError)?.reason, "To draw a view, install the Command Line Tools: xcode-select --install")
        }
    }

    func testALibraryBesideTheSourceIsUsedWithNoBuild() async throws {
        let views = try tools(selector: "exit 2")
        let file = try source()
        let carried = folder.appendingPathComponent("cups.view")
        try Data("carried".utf8).write(to: carried)

        let library = try await views.library(of: file)

        XCTAssertEqual(library.lastPathComponent, "cups.view")
    }

    @MainActor
    func testTheCheckNamesAViewThatIsMissingOrDoesNotCompile() async throws {
        let plugins = folder.appendingPathComponent("plugins")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try "#!/bin/sh\n# view=lost.swift\n".writeScript(to: plugins.appendingPathComponent("lost.sh"))
        try "#!/bin/sh\n# view=bad.swift\n".writeScript(to: plugins.appendingPathComponent("bad.sh"))
        try Data("struct".utf8).write(to: plugins.appendingPathComponent("bad.swift"))
        let views = try tools(compiler: "echo 'bad.swift:1:7: error: expected identifier' >&2; exit 1")

        let faults = await PluginCheck(folder: PluginFolder(url: plugins), views: views).faults()

        XCTAssertEqual(faults, [
            "bad: This view does not compile. bad.swift:1:7: error: expected identifier",
            "lost: Openspot cannot find the view lost.swift."
        ])
    }
}
