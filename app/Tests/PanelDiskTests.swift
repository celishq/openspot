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

    private let reads = Reads()
    private let discards = Reads()

    override func setUp() async throws {
        try await super.setUp()
        model.quit()
        let reads = reads
        let discards = discards
        let trash = folder.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults,
            trash: { url in
                discards.add()
                try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(url.lastPathComponent))
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
        try script("shelf", toml: "title = 'Shelf'\n[on]\ndrop = ['mov']", "true")
        try script("notes", toml: "title = 'Notes'\n[on]\ndrop = ['txt']", "true")
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
        try script("shelf", toml: "title = 'Shelf'\n[on]\ndrop = ['mov']", "true")
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

    func testAPastedSpotFileOpensTheStoreAtIt() async throws {
        await model.reload()
        model.isShown = true
        let file = folder.appendingPathComponent("Tea.spot")
        try SpotPackage(files: [.init(path: "tea.spot/tea.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]).zip(to: file)
        host.pastedPaths = [file.path]

        XCTAssertTrue(model.pasteSpot())

        XCTAssertEqual(host.openedStores, [file])
        XCTAssertFalse(model.isReviewing)
    }

    func testADroppedSpotFileOpensTheStoreAndNoPanelReview() async throws {
        await model.reload()
        model.isShown = true
        let package = folder.appendingPathComponent("drop/tea.spot")

        model.openInStore([package])

        XCTAssertEqual(host.openedStores, [package])
        XCTAssertFalse(model.isReviewing)
        XCTAssertNil(model.flow.current)
    }

    func testAWriteOfTheDraggedSpotOrOfThePointerMakesNoChangeOfItsOwn() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let drop = SpotDrop(paths: [file("broken.spot")], folder: folder)
        let changes = host.motions.count

        model.isPointerOverDrop = true
        model.draggedSpot = drop
        model.isPointerOverDrop = false
        model.draggedSpot = nil

        XCTAssertEqual(host.motions.count, changes)
    }

    func testASpotFileOverThePanelGrowsItsDropAndShrinksItWhenThePointerLeaves() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let package = folder.appendingPathComponent("broken.spot").path
        FileManager.default.createFile(atPath: package, contents: Data("no zip".utf8))
        host.draggedPaths = [package]
        host.isMouseDown = true
        host.isPointerOverDrop = true

        model.followDrag()
        try await wait("the drop") { self.model.showsFieldDrop }
        host.isPointerOverDrop = false
        try await wait("the drop gone") { !self.model.showsFieldDrop }
        host.isMouseDown = false

        XCTAssertEqual(host.fieldDropWrites.map(\.motion), [.sheet(isOpen: true), .sheet(isOpen: false)])
        XCTAssertEqual(host.fieldDropWrites.map(\.depth), [0, 0])
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
        try await wait("the words of the drop") { self.model.spotDrop?.title == "Cannot open broken" }
        host.isMouseDown = false
        XCTAssertEqual(reads.count, 0)
    }

    func testDeleteMovesTheFilesAwayFromTheMainThread() async throws {
        try script("gone", toml: "title = 'Gone'", "true")
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
    }
}
