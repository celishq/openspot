import XCTest
@testable import OpenspotCore

final class ViewLibraryTests: XCTestCase {
    private var folder: URL!
    private let view = "import SwiftUI\n\nstruct SpotView: View {\n    let spot: SpotInput\n    var body: some View {\n        Text(spot[\"title\"] ?? \"–\").font(spot.font.title).foregroundStyle(spot.ink.opacity(spot.secondary))\n            .padding(spot.inset).background(spot.accent, in: RoundedRectangle(cornerRadius: spot.corner))\n            .frame(width: spot.size.width)\n    }\n}\n"

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
        try "#!/bin/sh\nwhile [ $# -gt 0 ]; do [ \"$1\" = -output ] && printf both > \"$2\"; shift; done\n".writeScript(to: place.appendingPathComponent("lipo"))
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
            XCTAssertEqual((error as? SpotError)?.reason, "This view does not compile. cups.swift:5:9: error: cannot find x in scope")
        }
    }

    func testAMacWithNoToolsSaysHowToGetThem() async throws {
        let views = try tools(selector: "exit 2")

        do {
            _ = try await views.library(of: try source())
            XCTFail("It must not build.")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "To draw a view, install the Command Line Tools: xcode-select --install")
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
        for name in ["lost", "bad"] {
            try FileManager.default.createDirectory(at: plugins.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try "#!/bin/sh\n# view=lost.swift\n".writeScript(to: plugins.appendingPathComponent("lost/lost.sh"))
        try "#!/bin/sh\n# view=bad.swift\n".writeScript(to: plugins.appendingPathComponent("bad/bad.sh"))
        try Data("struct".utf8).write(to: plugins.appendingPathComponent("bad/bad.swift"))
        let views = try tools(compiler: "echo 'bad.swift:1:7: error: expected identifier' >&2; exit 1")

        let faults = await SpotCheck(folder: SpotFolder(url: plugins), views: views).faults()

        XCTAssertEqual(faults, [
            "bad/bad: This view does not compile. bad.swift:1:7: error: expected identifier",
            "lost/lost: Openspot cannot find the view lost.swift."
        ])
    }

    private var sharedCups: SharedSpot {
        get throws {
            try SharedSpot(files: [
                .init(path: "home/cups.sh", isExecutable: true, contents: Data("#!/bin/sh\n# view=cups.swift\n".utf8)),
                .init(path: "home/cups.swift", isExecutable: false, contents: Data(view.utf8))
            ])
        }
    }

    func testASharedSpotTravelsWithAViewBuiltForBothKindsOfMac() async throws {
        let spot = try sharedCups

        XCTAssertTrue(spot.needsCompile)
        let compiled = try await spot.compiled(views: try tools())

        XCTAssertFalse(compiled.needsCompile)
        XCTAssertEqual(compiled.files.map(\.path), ["home/cups.sh", "home/cups.swift", "home/cups.view"])
        XCTAssertEqual(compiled.files.last?.contents, Data("both".utf8))
        XCTAssertEqual(compiled.files.last?.isExecutable, false)
    }

    func testTheReviewSaysThatAViewLibraryIsCodeThatMayNotMatchItsSource() throws {
        var files = try sharedCups.files
        files.append(.init(path: "home/cups.view", isExecutable: false, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x00])))

        let review = try ReviewSpot(spot: try SharedSpot(files: files), folder: folder)

        XCTAssertEqual(review.subtitle, "Holds a program that you cannot read")
        let part = try XCTUnwrap(SpotOutput(text: try review.answer(["read"])).parts.first { $0.id == "review" })
        guard case .text(let text, _, _) = part.control else { throw SpotError.badForm }
        XCTAssertTrue(text.hasPrefix("Program that Openspot cannot show\nhome/cups.view\nIt can do all that you can. Add it only if you trust the sender.\nThe source beside it may not match the program.\n\n"), text)
    }

    func testRemovingASpotAlsoTakesItsViewAndItsLibrary() throws {
        let plugins = folder.appendingPathComponent("plugins")
        let cups = plugins.appendingPathComponent("cups")
        try FileManager.default.createDirectory(at: cups, withIntermediateDirectories: true)
        try "#!/bin/sh\n# view=cups.swift\n".writeScript(to: cups.appendingPathComponent("cups.sh"))
        try "#!/bin/sh\n".writeScript(to: cups.appendingPathComponent("other.sh"))
        try Data(view.utf8).write(to: cups.appendingPathComponent("cups.swift"))
        try Data("built".utf8).write(to: cups.appendingPathComponent("cups.view"))
        let place = SpotFolder(url: plugins)
        let spot = try XCTUnwrap(try place.scan().spots.first { $0.id == "cups/cups" })
        var discarded: [String] = []

        try place.remove(spot) { discarded.append($0.lastPathComponent) }

        XCTAssertEqual(discarded, ["cups.sh", "cups.swift", "cups.view"])
    }
}
