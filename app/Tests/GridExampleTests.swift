import XCTest
@testable import OpenspotCore

/// Proves the Grid example: the block of cells it gives `openspot window move`, and how its script runs the grid.
final class GridExampleTests: SampleSpotsCase {
    /// A stand-in for the openspot command that logs each call to `calls`, and a stand-in grid in the data folder of the
    /// spot that runs this body. Its file is newer than the source, so the script does not build it.
    private func fakeGrid(_ body: String, in folder: URL) throws -> URL {
        try "#!/bin/sh\necho \"$*\" >> '\(folder.path)/calls'\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
        let data = folder.appendingPathComponent(".config/openspot/data/grid")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try "#!/bin/sh\n\(body)\n".writeScript(to: data.appendingPathComponent("grid"))
        return data
    }

    private func calls(in folder: URL) -> String {
        (try? read("calls", in: folder)) ?? ""
    }

    func testTheGridGivesTheBlockBetweenTwoCornersAsPartsOfTheScreen() async throws {
        let (folder, grid) = try await built("grid")
        defer { try? FileManager.default.removeItem(at: folder) }

        func pick(_ numbers: Int...) async throws -> String {
            try await ScriptProcess.output(url: grid, arguments: ["pick"] + numbers.map(String.init))
        }

        let forward = try await pick(6, 6, 1, 1, 4, 3)
        let backward = try await pick(6, 6, 4, 3, 1, 1)
        let whole = try await pick(6, 6, 0, 0, 5, 5)
        let one = try await pick(6, 6, 2, 5, 2, 5)
        let outside = try await pick(6, 6, -2, 0, 9, 0)
        XCTAssertEqual(forward, "1/6 1/6 4/6 3/6\n")
        XCTAssertEqual(backward, forward)
        XCTAssertEqual(whole, "0 0 1 1\n")
        XCTAssertEqual(one, "2/6 5/6 1/6 1/6\n")
        XCTAssertEqual(outside, "0 0 1 1/6\n")
    }

    func testTheGreyBlockOfEachPickIsTheFrameThatTheMoveGivesTheWindowOnEachScreen() async throws {
        let (folder, grid) = try await built("grid")
        defer { try? FileManager.default.removeItem(at: folder) }
        let areas = [
            CGRect(x: 0, y: 33, width: 1728, height: 1084),
            CGRect(x: 0, y: 25, width: 1440, height: 875),
            CGRect(x: -1920, y: -200, width: 1920, height: 1055),
            CGRect(x: 1728, y: 0, width: 2560, height: 1415),
            CGRect(x: 0, y: 38, width: 1511, height: 943),
        ]
        var checked = 0

        for area in areas {
            let numbers = [6, 6, area.minX, area.minY, area.width, area.height].map { String(Int($0)) }
            let lines = try await ScriptProcess.output(url: grid, arguments: ["frames"] + numbers).split(separator: "\n")
            for line in lines {
                let parts = line.split(separator: "|")
                let drawn = parts[1].split(separator: " ").compactMap { Double($0) }
                let move = try XCTUnwrap(WindowMove(words: [String(parts[0])]))
                let moved = move.target(window: .zero, area: area)
                XCTAssertEqual(CGRect(x: drawn[0], y: drawn[1], width: drawn[2], height: drawn[3]), moved, "\(parts[0]) on \(area)")
                checked += 1
            }
        }

        XCTAssertEqual(checked, 5 * 666)
    }

    func testARunMovesTheFrontWindowToTheBlockThatThePersonPicks() async throws {
        let grid = try example("Grid")
        try await withPrivateHome { folder in
            _ = try self.fakeGrid("echo '0 0 1/2 1'", in: folder)

            _ = try await grid.perform(.open, timeout: 5)

            XCTAssertEqual(self.calls(in: folder), "window move 0 0 1/2 1\n")
        }
    }

    func testARunWithoutAccessibilityOpensItsSettingsAndShowsNoFailure() async throws {
        let grid = try example("Grid")
        try await withPrivateHome { folder in
            _ = try self.fakeGrid("echo '0 0 1/2 1'", in: folder)
            let link = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            try "#!/bin/sh\necho link=\(link)\necho 'Openspot cannot move the window.' >&2\nexit 1\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
            try "#!/bin/sh\necho \"$*\" >> '\(folder.path)/opened'\n".writeScript(to: folder.appendingPathComponent("tools/open"))

            _ = try await grid.perform(.open, timeout: 5)

            XCTAssertEqual(try self.read("opened", in: folder), "\(link)\n")
        }
    }

    func testARunThatThePersonCancelsMovesNothing() async throws {
        let grid = try example("Grid")
        try await withPrivateHome { folder in
            _ = try self.fakeGrid("true", in: folder)

            _ = try await grid.perform(.open, timeout: 5)

            XCTAssertEqual(self.calls(in: folder), "")
        }
    }

    func testARunShowsTheGridThatWaitsAndMovesNothingItself() async throws {
        let grid = try example("Grid")
        try await withPrivateHome { folder in
            let shown = folder.appendingPathComponent("shown")
            let data = try self.fakeGrid("echo '0 0 1 1'", in: folder)
            let waiting = try TestChild("/bin/sh", ["-c", "trap 'touch \(shown.path)' USR1; while [ ! -f \(shown.path) ]; do sleep 0.05; done"])
            defer { waiting.stop() }
            try String(waiting.processIdentifier).write(to: data.appendingPathComponent("grid.pid"), atomically: true, encoding: .utf8)

            _ = try await grid.perform(.open, timeout: 5)
            try await self.waitUntil { FileManager.default.fileExists(atPath: shown.path) }

            XCTAssertTrue(FileManager.default.fileExists(atPath: shown.path))
            XCTAssertEqual(self.calls(in: folder), "")
        }
    }

    func testASecondGridThatWouldWaitEndsAtOnceAndLeavesTheOneThatWaits() async throws {
        let (folder, grid) = try await built("grid")
        defer { try? FileManager.default.removeItem(at: folder) }
        let pidfile = folder.appendingPathComponent("grid.pid")
        try "1".write(to: pidfile, atomically: true, encoding: .utf8)
        let held = open(folder.appendingPathComponent("grid.lock").path, O_RDWR | O_CREAT, 0o644)
        defer { close(held) }
        XCTAssertEqual(flock(held, LOCK_EX), 0)
        let parent = try TestChild("/bin/sleep", ["600"])
        defer { parent.stop() }

        let second = Process()
        second.executableURL = grid
        second.arguments = ["stay", String(parent.processIdentifier)]
        try second.run()
        defer { kill(second.processIdentifier, SIGKILL) }
        try await waitUntil { !second.isRunning }

        XCTAssertFalse(second.isRunning)
        XCTAssertEqual(try String(contentsOf: pidfile, encoding: .utf8), "1")
    }

    func testAReadAfterARebuildStartsTheNewGridOnceTheOldOneHasEnded() async throws {
        let (folder, grid) = try await built("grid")
        defer { try? FileManager.default.removeItem(at: folder) }
        let data = folder.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        let holder = folder.appendingPathComponent("holder.py")
        try """
        import fcntl, os, signal, sys, time
        lock = open(sys.argv[1] + '/grid.lock', 'a')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        pidfile = open(sys.argv[1] + '/grid.pid', 'w')
        fcntl.flock(pidfile, fcntl.LOCK_EX | fcntl.LOCK_NB)
        signal.signal(signal.SIGTERM, lambda *_: (time.sleep(0.5), os._exit(0)))
        pidfile.write(str(os.getpid()))
        pidfile.flush()
        while True:
            signal.pause()
        """.write(to: holder, atomically: true, encoding: .utf8)
        let old = Process()
        old.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        old.arguments = [holder.path, data.path]
        try old.run()
        defer { old.terminate() }
        let pidfile = data.appendingPathComponent("grid.pid")
        func named() -> pid_t? { pid_t((try? String(contentsOf: pidfile, encoding: .utf8)) ?? "") }
        try await waitUntil { named() != nil }
        let copy = data.appendingPathComponent("grid")
        try FileManager.default.copyItem(at: grid, to: copy)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: copy.path)

        let read = Process()
        read.executableURL = URL(fileURLWithPath: "/bin/sh")
        read.arguments = [examples.appendingPathComponent("grid.spot/grid.sh").path, "read"]
        read.environment = ["PATH": "/usr/bin:/bin", "OPENSPOT_DATA": data.path, "OPENSPOT_REASON": "panel.open"]
        try read.run()
        defer { read.terminate() }
        try await waitUntil { !old.isRunning && named().map { $0 == old.processIdentifier || kill($0, 0) != 0 } == false }
        defer { if let new = named() { kill(new, SIGKILL) } }

        XCTAssertFalse(old.isRunning)
        XCTAssertNotEqual(named(), old.processIdentifier)
        XCTAssertEqual(named().map { kill($0, 0) }, 0)
    }

    func testAReadWithNoReasonStartsNoGrid() async throws {
        let grid = try example("Grid")
        try await withPrivateHome { folder in
            let data = try self.fakeGrid("touch '\(folder.path)/started'", in: folder)

            _ = try await grid.items(timeout: 5)

            XCTAssertFalse(FileManager.default.fileExists(atPath: data.appendingPathComponent("grid.pid").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("started").path))
        }
    }
}
