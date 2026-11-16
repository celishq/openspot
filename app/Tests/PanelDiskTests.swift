import Synchronization
import XCTest
@testable import OpenspotCore

@MainActor
final class PanelDiskTests: PanelCase {
    private final class Reads: Sendable {
        private let counts = Mutex<(all: Int, onMain: Int)>((0, 0))

        var count: Int {
            counts.withLock { $0.all }
        }

        var countOnMain: Int {
            counts.withLock { $0.onMain }
        }

        func add() {
            let isMain = Thread.isMainThread
            counts.withLock {
                $0.all += 1
                if isMain { $0.onMain += 1 }
            }
        }
    }

    private final class Slow: Sendable {
        private let held = Mutex<(name: String, gate: DispatchSemaphore)?>(nil)

        func hold(_ name: String, behind gate: DispatchSemaphore) {
            held.withLock { $0 = (name, gate) }
        }

        func wait(for file: String) {
            if let held = held.withLock({ $0 }), file.hasPrefix(held.name) { held.gate.wait() }
        }
    }

    private let reads = Reads()
    private let discards = Reads()
    private let slow = Slow()

    override func setUp() async throws {
        try await super.setUp()
        model.quit()
        let reads = reads
        let discards = discards
        let slow = slow
        let trash = folder.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults,
            trash: { url in
                discards.add()
                slow.wait(for: url.lastPathComponent)
                let place = trash.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.moveItem(at: url, to: place)
                return place
            },
            kinds: { paths in
                reads.add()
                return FileKinds.Disk().read(paths)
            }
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
    }

    private func file(_ name: String) -> String {
        let path = folder.appendingPathComponent(name).path
        FileManager.default.createFile(atPath: path, contents: Data())
        return path
    }

    func testADragReadsItsFilesOnceAwayFromTheMainThreadAndEachTickReadsNone() async throws {
        try script("shelf", header: "title=Shelf\non=sheet.open\ndrop=mov", "true")
        try script("notes", header: "title=Notes\non=sheet.open\ndrop=txt", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let movie = file("a.mov")
        host.draggedPaths = [movie]
        host.isMouseDown = true

        model.followDrag()

        XCTAssertEqual(reads.count, 0)
        XCTAssertFalse(model.acceptsDrop([movie], on: "shelf"))
        XCTAssertFalse(model.drop([movie], on: "shelf"))
        XCTAssertEqual(reads.count, 0)
        try await wait("the cards that take the drag") { self.model.takesDrag("shelf") }
        for _ in 0..<5 {
            model.followDrag()
            XCTAssertTrue(model.acceptsDrop([movie], on: "shelf"))
            XCTAssertFalse(model.acceptsDrop([movie], on: "notes"))
            XCTAssertFalse(model.takesDrag("notes"))
        }
        XCTAssertTrue(model.drop([movie], on: "shelf"))
        host.isMouseDown = false

        XCTAssertEqual(reads.count, 1)
        XCTAssertEqual(reads.countOnMain, 0)
    }

    func testACheckOfADropThatNoDragBroughtReadsNothingAndTellsNoReader() async throws {
        try script("shelf", header: "title=Shelf\non=sheet.open\ndrop=mov", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let movie = file("a.mov")
        nonisolated(unsafe) var told = false
        withObservationTracking { _ = (model.draggedSpot, model.dragPaths, model.takesDrag("shelf")) } onChange: { told = true }

        XCTAssertFalse(model.acceptsDrop([movie], on: "shelf"))
        XCTAssertFalse(model.drop([movie], on: "shelf"))

        XCTAssertFalse(told)
        XCTAssertNil(model.dragRead)
        XCTAssertEqual(reads.count, 0)
    }

    func testAReviewThatLandsAfterThePanelClosedIsDropped() async throws {
        try script("cups", header: "title=Cups", "true")
        await model.reload()
        model.isShown = true
        let package = folder.appendingPathComponent("drop/tea.spot")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try "#!/bin/sh\n# title=Tea\n:\n".writeScript(to: package.appendingPathComponent("tea.sh"))

        model.review([package])
        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        XCTAssertEqual(host.dismissals, 1)
        await model.reviewRead?.value

        XCTAssertFalse(model.isReviewing)
        XCTAssertNil(model.flow.current)
        XCTAssertEqual(host.presents, 0)
    }

    func testCommandZRightAfterADeleteNeverUndoesAnOlderRemoval() async throws {
        try script("first", header: "title=First", "true")
        try script("second", header: "title=Second", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        XCTAssertTrue(model.act(.delete, on: "first"))
        try await wait("the first toast") { self.host.confirms.contains { $0.hasPrefix("Moved First") } }
        let gate = DispatchSemaphore(value: 0)
        slow.hold("second", behind: gate)

        XCTAssertTrue(model.act(.delete, on: "second"))
        XCTAssertFalse(model.handleKey(ActionKey(name: "z", isCommand: true)))
        gate.signal()

        try await wait("the second toast") { self.host.confirms.contains { $0.hasPrefix("Moved Second") } }
        XCTAssertNil(model.card(id: "first"))
    }

    func testOnlyTheLatestDeleteIsTheOneThatCommandZPutsBack() async throws {
        try script("first", header: "title=First", "true")
        try script("second", header: "title=Second", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let gate = DispatchSemaphore(value: 0)
        slow.hold("first", behind: gate)

        XCTAssertTrue(model.act(.delete, on: "first"))
        XCTAssertTrue(model.act(.delete, on: "second"))
        try await wait("the second toast") { self.host.confirms.contains { $0.hasPrefix("Moved Second") } }
        gate.signal()
        try await wait("the first toast") { self.host.confirms.contains { $0.hasPrefix("Moved First") } }

        XCTAssertTrue(model.handleKey(ActionKey(name: "z", isCommand: true)))
        try await wait("the spot again") { self.host.confirms.last == "Put Second back." }
        XCTAssertNotNil(model.card(id: "second"))
        XCTAssertNil(model.card(id: "first"))
    }

    func testASpotFileOverThePanelIsOpenedAwayFromThePress() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let package = folder.appendingPathComponent("broken.spot").path
        FileManager.default.createFile(atPath: package, contents: Data("no zip".utf8))
        host.draggedPaths = [package]
        host.isMouseDown = true
        host.isPointerOverDrop = true

        model.followDrag()

        XCTAssertNil(model.draggedSpot)
        try await wait("the words of the drop") { self.model.spotDrop?.title == "Cannot install broken" }
        host.isMouseDown = false
        XCTAssertEqual(reads.count, 0)
    }

    func testAReviewOpensItsFileAwayFromThePress() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let package = folder.appendingPathComponent("broken.spot")
        FileManager.default.createFile(atPath: package.path, contents: Data("no zip".utf8))

        model.review([package])

        XCTAssertEqual(host.notes, [])
        try await wait("the reason") { self.host.notes == ["This file is not a spot."] }
    }

    func testDeleteMovesTheFilesAwayFromTheMainThreadAndCommandZPutsThemBack() async throws {
        try script("gone", header: "title=Gone", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        XCTAssertNotNil(model.card(id: "gone"))

        XCTAssertTrue(model.act(.delete, on: "gone"))

        XCTAssertEqual(discards.count, 0)
        try await wait("the toast") { self.host.confirms.contains { $0.hasPrefix("Moved Gone to the Trash") } }
        XCTAssertNil(model.card(id: "gone"))
        XCTAssertGreaterThan(discards.count, 0)
        XCTAssertEqual(discards.countOnMain, 0)

        XCTAssertTrue(model.handleKey(ActionKey(name: "z", isCommand: true)))
        try await wait("the spot again") { self.host.confirms.last == "Put Gone back." }
        XCTAssertNotNil(model.card(id: "gone"))
    }
}
