import SwiftUI
import Synchronization
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

    private var built: String {
        (ViewLibrary.path(beside: "cups.swift", text: Data(view.utf8)) as NSString).lastPathComponent
    }

    func testAViewBuildsIntoALibraryWithItsEntry() async throws {
        let library = try await ViewLibrary(cache: cache).library(of: try source())

        let handle = try XCTUnwrap(dlopen(library.path, RTLD_NOW | RTLD_LOCAL), String(cString: dlerror()))
        XCTAssertNotNil(dlsym(handle, ViewLibrary.entry))
    }

    private typealias Make = ([String: [String]], [String: Any], @escaping (String) -> Void) -> AnyView

    @MainActor
    private func drawn(_ text: String, values: [String: [String]], card: [String: Any]) async throws -> [String] {
        let library = try await ViewLibrary(cache: cache).library(of: try source("words.swift", text))
        let handle = try XCTUnwrap(dlopen(library.path, RTLD_NOW | RTLD_LOCAL), String(cString: dlerror()))
        let entry = unsafeBitCast(try XCTUnwrap(dlsym(handle, ViewLibrary.entry)), to: (@convention(c) () -> UnsafeMutableRawPointer).self)
        let make = try XCTUnwrap(Unmanaged<AnyObject>.fromOpaque(entry()).takeRetainedValue() as? Make)
        var sent: [String] = []
        let host = NSHostingView(rootView: make(values, card) { sent.append($0) })
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        host.layoutSubtreeIfNeeded()
        return sent
    }

    @MainActor
    func testAViewReadsTheRowsOfItsFrameAndWhetherItShowsAndClosesItsSheet() async throws {
        let text = """
        import SwiftUI

        struct SpotView: View {
            let spot: SpotInput
            @State private var word = "state"

            var body: some View {
                let rows = spot.rows.map { "\\($0.id):\\($0["title"] ?? "-"):\\($0.all("tag").joined(separator: "+"))" }
                let _ = spot.send("\\(word) \\(spot.isShown) \\(rows.joined(separator: ","))")
                let _ = spot.isShown ? () : spot.close()
                Text(word)
            }
        }

        """
        let rows = [["row", "a", "title", "One", "tag", "x", "tag", "y"], ["row", "b"]]
        var closed = 0
        var times: [Duration] = []
        let card: [String: Any] = ["isShown": false, "rows": rows, "close": { closed += 1 }, "bodyTime": { (time: Duration) in times.append(time) }]

        let sent = try await drawn(text, values: ["view": ["words"], "row": ["mine"]], card: card)

        XCTAssertEqual(sent, ["state false a:One:x+y,b:-:"])
        XCTAssertEqual(closed, 1)
        XCTAssertEqual(times.count, 1)
        XCTAssertGreaterThan(times.first ?? .zero, .zero)
    }

    @MainActor
    func testAViewWithNoHostWordsShowsAndHasNoRows() async throws {
        let sent = try await drawn(view.replacingOccurrences(of: "Text(", with: "let _ = spot.send(\"\\(spot.rows.count) \\(spot.isShown) \\(spot[\"row\"] ?? \"-\")\")\n        Text("), values: ["title": ["Hi"], "row": ["mine"]], card: [:])

        XCTAssertEqual(sent, ["0 true mine"])
    }

    @MainActor
    func testAViewReadsTheThemeByRole() async throws {
        let text = """
        import SwiftUI

        struct SpotView: View {
            let spot: SpotInput

            var body: some View {
                let theme = spot.theme
                let _ = spot.send("\\(theme.space.padding) \\(theme.space.gridWidth) \\(theme.radius.inner) \\(theme.motion.press) \\(theme.color.fill) \\(theme.color.secondary)")
                Text("theme").font(theme.font.body).foregroundStyle(theme.color.good)
            }
        }

        """
        let theme: [String: Any] = ["padding": CGFloat(20), "gridWidth": CGFloat(310), "inner": CGFloat(10), "press": CGFloat(0.3), "fill": CGFloat(0.25)]

        let sent = try await drawn(text, values: [:], card: ["theme": theme])

        XCTAssertEqual(sent, ["20.0 310.0 10.0 0.3 0.25 0.7"])
    }

    @MainActor
    func testAViewThatClosesFromAnotherThreadClosesOnTheMainThread() async throws {
        let text = """
        import SwiftUI

        struct SpotView: View {
            let spot: SpotInput

            var body: some View {
                let _ = Thread.detachNewThread { spot.close() }
                Text("close")
            }
        }

        """
        let threads = Mutex<[Bool]>([])
        let close: @Sendable () -> Void = { threads.withLock { $0.append(Thread.isMainThread) } }

        _ = try await drawn(text, values: [:], card: ["close": close as () -> Void])
        try await wait("the close") { !threads.withLock { $0 }.isEmpty }

        XCTAssertFalse(threads.withLock { $0 }.contains(false))
    }

    func testEachViewThatAScriptUnderAFolderNamesIsBuiltBesideItsSourceForBothKindsOfMac() async throws {
        let views = try tools()
        let spots = folder.appendingPathComponent("spots")
        let own = spots.appendingPathComponent("openspot.spot")
        try FileManager.default.createDirectory(at: own, withIntermediateDirectories: true)
        try "#!/bin/sh\n# title=Icon\n# view=icon.swift\n".writeScript(to: own.appendingPathComponent("icon.sh"))
        try Data(view.utf8).write(to: own.appendingPathComponent("icon.swift"))
        try "#!/bin/sh\n# title=Quit\n".writeScript(to: own.appendingPathComponent("quit.sh"))
        try Data(view.utf8).write(to: own.appendingPathComponent("loose.swift"))

        let built = try await views.buildViews(under: spots)

        let name = (ViewLibrary.path(beside: "icon.swift", text: Data(view.utf8)) as NSString).lastPathComponent
        XCTAssertEqual(built.map(\.lastPathComponent), [name])
        XCTAssertEqual(try Data(contentsOf: own.appendingPathComponent(name)), Data("both".utf8))
        XCTAssertEqual(builds, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: own.appendingPathComponent("loose.view").path))
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
        try Data("carried".utf8).write(to: folder.appendingPathComponent(built))

        let library = try await views.library(of: file)

        XCTAssertEqual(library.lastPathComponent, built)
    }

    func testALibraryBesideTheSourceWhoseNameHoldsNoHashOfItIsNotLoaded() async throws {
        let views = try tools()
        let file = try source()
        let stale = (ViewLibrary.path(beside: "cups.swift", text: Data("struct Old {}".utf8)) as NSString).lastPathComponent
        for name in ["cups.view", stale] { try Data("carried".utf8).write(to: folder.appendingPathComponent(name)) }

        let library = try await views.library(of: file)

        XCTAssertEqual(library.deletingLastPathComponent().standardizedFileURL, cache.standardizedFileURL)
        XCTAssertEqual(builds, 1)
    }

    @MainActor
    func testTheCheckNamesAViewThatIsMissingOrDoesNotCompile() async throws {
        let spots = folder.appendingPathComponent("spots")
        for name in ["lost", "bad"] {
            try FileManager.default.createDirectory(at: spots.appendingPathComponent(name + ".spot"), withIntermediateDirectories: true)
        }
        try "#!/bin/sh\n# view=lost.swift\n".writeScript(to: spots.appendingPathComponent("lost.spot/lost.sh"))
        try "#!/bin/sh\n# view=bad.swift\n".writeScript(to: spots.appendingPathComponent("bad.spot/bad.sh"))
        try Data("struct".utf8).write(to: spots.appendingPathComponent("bad.spot/bad.swift"))
        let views = try tools(compiler: "echo 'bad.swift:1:7: error: expected identifier' >&2; exit 1")

        let faults = await SpotCheck(folder: SpotsFolder(url: spots), views: views).faults()

        XCTAssertEqual(faults, [
            "bad: This view does not compile. bad.swift:1:7: error: expected identifier",
            "lost: Openspot cannot find the view lost.swift."
        ])
    }

    private var sharedCups: SpotPackage {
        get throws {
            try SpotPackage(files: [
                .init(path: "home.spot/cups.sh", isExecutable: true, contents: Data("#!/bin/sh\n# view=cups.swift\n".utf8)),
                .init(path: "home.spot/cups.swift", isExecutable: false, contents: Data(view.utf8))
            ])
        }
    }

    func testASharedSpotTravelsWithAViewBuiltForBothKindsOfMac() async throws {
        let spot = try sharedCups

        XCTAssertTrue(spot.needsCompile)
        let compiled = try await spot.compiled(views: try tools())

        XCTAssertFalse(compiled.needsCompile)
        XCTAssertEqual(compiled.files.map(\.path), ["home.spot/cups.sh", "home.spot/cups.swift", "home.spot/\(built)"])
        XCTAssertEqual(compiled.files.last?.contents, Data("both".utf8))
        XCTAssertEqual(compiled.files.last?.isExecutable, false)
    }

    func testTheReviewSaysThatAViewLibraryIsCodeThatMayNotMatchItsSource() throws {
        var files = try sharedCups.files
        files.append(.init(path: "home.spot/\(built)", isExecutable: false, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x00])))

        let review = try ReviewSpot(spot: try SpotPackage(files: files), folder: folder)

        XCTAssertEqual(review.subtitle, "Holds a program that you cannot read")
        let part = try XCTUnwrap(SpotOutput(text: try review.answer(["read"])).parts.first { $0.id == "review" })
        guard case .text(let text, _, _) = part.control else { throw SpotError.badForm }
        XCTAssertTrue(text.hasPrefix("\(review.name)\n\nProgram that Openspot cannot show\nhome.spot/\(built)\nIt can do all that you can. Add it only if you trust the sender.\nThe source beside it may not match the program.\n\n"), text)
    }

    func testRemovingASpotAlsoTakesItsViewAndItsLibrary() throws {
        let spots = folder.appendingPathComponent("spots")
        let cups = spots.appendingPathComponent("cups.spot")
        try FileManager.default.createDirectory(at: cups, withIntermediateDirectories: true)
        try "#!/bin/sh\n# view=cups.swift\n".writeScript(to: cups.appendingPathComponent("cups.sh"))
        try "#!/bin/sh\n".writeScript(to: cups.appendingPathComponent("other.sh"))
        try Data(view.utf8).write(to: cups.appendingPathComponent("cups.swift"))
        try Data("built".utf8).write(to: cups.appendingPathComponent(built))
        let place = SpotsFolder(url: spots)
        let spot = try XCTUnwrap(try place.scan().spots.first { $0.id == "cups" })
        var discarded: [String] = []

        try place.remove(spot) { discarded.append($0.lastPathComponent) }

        XCTAssertEqual(discarded, ["cups.sh", "cups.swift", built])
    }

    func testAShareLeavesOutALibraryThatDoesNotMatchItsSource() throws {
        let spots = folder.appendingPathComponent("spots")
        let cups = spots.appendingPathComponent("cups.spot")
        try FileManager.default.createDirectory(at: cups, withIntermediateDirectories: true)
        try "#!/bin/sh\n# view=cups.swift\n".writeScript(to: cups.appendingPathComponent("cups.sh"))
        try Data(view.utf8).write(to: cups.appendingPathComponent("cups.swift"))
        let stale = (ViewLibrary.path(beside: "cups.swift", text: Data("struct Old {}".utf8)) as NSString).lastPathComponent
        for name in [built, stale] { try Data("built".utf8).write(to: cups.appendingPathComponent(name)) }
        let scan = try SpotsFolder(url: spots).scan()
        let spot = try XCTUnwrap(scan.spots.first { $0.id == "cups" })

        let shared = try SpotPackage(sharing: spot, from: scan)

        XCTAssertEqual(shared.files.map(\.path), ["cups.spot/\(built)", "cups.spot/cups.sh", "cups.spot/cups.swift"])
    }

    func testABuildBesideTheSourceRemovesItsOldLibrary() async throws {
        let spots = folder.appendingPathComponent("spots")
        let own = spots.appendingPathComponent("cups.spot")
        try FileManager.default.createDirectory(at: own, withIntermediateDirectories: true)
        try "#!/bin/sh\n# view=cups.swift\n".writeScript(to: own.appendingPathComponent("cups.sh"))
        try Data(view.utf8).write(to: own.appendingPathComponent("cups.swift"))
        let stale = (ViewLibrary.path(beside: "cups.swift", text: Data("struct Old {}".utf8)) as NSString).lastPathComponent
        try Data("old".utf8).write(to: own.appendingPathComponent(stale))

        _ = try await tools().buildViews(under: spots)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: own.path).sorted(), [built, "cups.sh", "cups.swift"].sorted())
    }
}
