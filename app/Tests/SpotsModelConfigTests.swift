import XCTest
@testable import OpenspotCore

@MainActor
final class SpotsModelConfigTests: PanelCase {
    private var disk: FakeDisk!

    override func setUp() async throws {
        try await super.setUp()
        model.quit()
        let host = FakeHost()
        self.host = host
        disk = FakeDisk()
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults,
            disk: disk
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
        for name in ["a", "b", "c"] { try script(name, toml: "title = '\(name)'", ":") }
        await model.reload()
    }

    func testASectionThatAChangeDoesNotNameIsNotLost() async throws {
        try model.files.config.change { $0.set(columns: GridColumns(6)) }

        model.configChanged(.keys, to: model.files.config.readKept())
        await model.spotsChanged()

        XCTAssertEqual(model.columns, GridColumns(6))
    }

    func testAChangeThatTheAPIHandsOverReadsNoConfigFromTheDisk() throws {
        let trigger = try XCTUnwrap(Trigger(text: "ctrl+option+l"))
        let next = try model.files.config.change { $0.assign(trigger, to: "a", act: .float) }
        let reads = disk.reads

        model.configChanged(.keys, to: next)
        model.configChanged(.careful, to: next)
        model.configChanged(.value(spot: "a", caller: nil), to: next)
        model.configChanged(.spots(["a"]), to: next)

        XCTAssertEqual(disk.reads, reads)
        XCTAssertEqual(model.config, next.config)
    }

    func testAKeyOfTheAppACarefulModeAndAPanelBuildNoGrid() async throws {
        let builds = model.gridBuilds
        let key = try XCTUnwrap(Shortcut(text: "option+space"))

        model.configChanged(.keys, to: try model.files.config.change { $0.set(key, for: "panel-key") })
        model.configChanged(.careful, to: try model.files.config.change { $0.set(isCareful: true) })
        model.set(columns: GridColumns(6))
        await model.spotsChanged()

        XCTAssertEqual(model.gridBuilds, builds)
        XCTAssertEqual(model.columns, GridColumns(6))
        XCTAssertEqual(model.config, Config(text: disk.text ?? ""))
    }

    func testAnEditKeyReadsNoConfigFromTheDisk() throws {
        model.beginEditing()
        let reads = disk.reads
        var writes = disk.writes
        let wrote = { () -> Bool in
            defer { writes = self.disk.writes }
            return self.disk.writes == writes + 1
        }

        _ = model.handleKey(ActionKey(name: "right", isShift: true))
        XCTAssertTrue(wrote())
        _ = model.handleKey(ActionKey(name: "left", isShift: true))
        XCTAssertTrue(wrote())
        _ = model.handleKey(ActionKey(name: "s"))
        XCTAssertTrue(wrote())
        model.set(columns: GridColumns(6))
        XCTAssertTrue(wrote())
        model.prefer(.large, for: "b")
        model.turnOff("c")

        XCTAssertEqual(disk.reads, reads)
        XCTAssertEqual(host.notes, [])
        XCTAssertEqual(model.config, Config(text: disk.text ?? ""))
    }

    func testAFailedWriteLeavesTheGridAsItWasAndShowsAToast() throws {
        model.beginEditing()
        let order = model.visible.map(\.id)
        let config = model.config
        disk.fail(true)

        let placements = model.placements
        model.moveSpot(order[0], to: GridCell(row: 3, column: 0))
        model.prefer(.large, for: order[0])
        model.set(columns: GridColumns(6))

        XCTAssertEqual(model.visible.map(\.id), order)
        XCTAssertEqual(model.placements, placements)
        XCTAssertEqual(model.config, config)
        XCTAssertEqual(model.columns, GridColumns())
        XCTAssertEqual(host.notes.count, 3)
        XCTAssertTrue(host.notes.allSatisfy { $0.hasPrefix("Openspot could not save the ") })
    }

    func testAChangeThatArrivesLateDoesNotPutBackAnOldConfig() throws {
        model.beginEditing()
        let trigger = try XCTUnwrap(Trigger(text: "ctrl+option+l"))
        let early = try model.files.config.change { $0.assign(trigger, to: "a", act: .float) }
        let first = try model.files.config.change { $0.arrangement.set(isEnabled: true, of: "x") }
        let second = try model.files.config.change { $0.arrangement.set(isEnabled: true, of: "y") }
        model.configChanged(.spots(["y"]), to: second)
        model.prefer(.small, for: "a")
        let config = model.config

        model.configChanged(.keys, to: early)
        model.configChanged(.spots(["x"]), to: first)

        XCTAssertEqual(model.config, config)
        XCTAssertEqual(model.visible.first { $0.id == "a" }?.size, .small)
        model.prefer(.small, for: "b")
        let written = Config(text: disk.text ?? "")
        XCTAssertEqual(written.arrangement.size(of: "a"), .small)
        XCTAssertEqual(written.arrangement.size(of: "b"), .small)
        XCTAssertEqual(written.arrangement.enabled, ["x", "y"])
        XCTAssertEqual(written.keys.map(\.trigger), [trigger])
    }

    func testAnEditKeepsTheChangeOfAnotherCallerThatTheModelHasNotSeen() throws {
        model.beginEditing()
        try model.files.config.change { $0.arrangement.set(isInMenuBar: true, of: "z") }

        model.prefer(.small, for: "a")
        try model.files.config.change { $0.arrangement.set(isEnabled: true, of: "y") }
        model.moveSpot("b", to: GridCell(row: 5, column: 0))
        try model.files.config.change { $0.arrangement.set(isEnabled: true, of: "w") }
        model.moveSpot("c", to: GridCell(row: 6, column: 0))

        let written = Config(text: disk.text ?? "")
        XCTAssertEqual(written.arrangement.menuBar, ["z"])
        XCTAssertEqual(written.arrangement.enabled, ["y", "w"])
        XCTAssertEqual(written.arrangement.size(of: "a"), .small)
        XCTAssertEqual(written.arrangement.cells(of: "b"), [4: GridCell(row: 5, column: 0)])
        XCTAssertEqual(written.arrangement.cells(of: "c"), [4: GridCell(row: 6, column: 0)])
        XCTAssertEqual(host.notes, [])
    }
}
