import XCTest
@testable import OpenspotCore

final class SheetHeldAnswerTests: PanelCase {
    override var motionLength: TimeInterval? {
        30
    }

    private func gated() throws {
        let f = folder.path
        try script("list", toml: "title = 'List'\n[on]\n\"panel.open\" = true", """
        n=$(( $(cat '\(f)/n' 2>/dev/null || echo 0) + 1 )); echo $n > '\(f)/n'
        [ $n -gt 1 ] && while [ ! -f '\(f)/gate' ]; do /bin/sleep 0.02; done
        printf 'frame=\\ndetail=D%s\\n\\nitem=a\\ntitle=A%s\\n' $n $n
        touch '\(f)/printed'$n
        """)
    }

    private func openOnce() async throws -> SpotRun {
        try gated()
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("list")
        try await wait("the open list") { self.model.transition.phase == .open && self.titles == ["A1"] }
        return try XCTUnwrap(model.sheets["list"])
    }

    private func printed(_ n: Int) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent("printed\(n)").path)
    }

    private func release() {
        FileManager.default.createFile(atPath: folder.appendingPathComponent("gate").path, contents: Data())
    }

    private func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }

    private func tracking(_ sheet: SpotRun) -> Told {
        let told = Told()
        withObservationTracking { _ = sheet.list; _ = sheet.state } onChange: { MainActor.assumeIsolated { told.count += 1 } }
        return told
    }

    @MainActor
    private final class Told {
        var count = 0
    }

    private func ends() {
        while let end = host.heldEnds?.first {
            host.heldEnds?.removeFirst()
            end()
        }
        host.heldEnds = nil
    }

    func testWhatASheetPrintsWhileItOpensTellsNoReaderUntilItsOpenMotionEnds() async throws {
        let sheet = try await openOnce()
        model.closeSheet(moving: false)
        host.heldEnds = []
        model.press("list")
        try await wait("the opening") { self.model.transition.phase == .opening }
        sheet.show(need: .change)
        let told = tracking(sheet)

        release()
        try await wait("the second print") { self.printed(2) }
        await settle()

        XCTAssertEqual(told.count, 0)
        XCTAssertEqual(sheet.list.shown.map(\.title), ["A1"])
        ends()
        try await wait("the held rows") { sheet.list.shown.map(\.title) == ["A2"] }
        XCTAssertEqual(told.count, 1)
    }

    func testWhatASheetPrintsWhileItClosesTellsNoReaderUntilItsCloseMotionEnds() async throws {
        let sheet = try await openOnce()
        sheet.show(need: .change)
        host.heldEnds = []
        model.closeSheet(moving: true)
        XCTAssertEqual(model.transition.phase, .closing)
        let told = tracking(sheet)

        release()
        try await wait("the second print") { self.printed(2) }
        await settle()

        XCTAssertEqual(told.count, 0)
        XCTAssertEqual(sheet.list.shown.map(\.title), ["A1"])
        ends()
        try await wait("the held rows") { sheet.list.shown.map(\.title) == ["A2"] }
        XCTAssertEqual(told.count, 1)
    }

    func testWhatASheetPrintsWhileAClosePressCutsItsOpenShortWaitsForTheCloseToEnd() async throws {
        let sheet = try await openOnce()
        model.closeSheet(moving: false)
        host.heldEnds = []
        model.press("list")
        try await wait("the opening") { self.model.transition.phase == .opening }
        sheet.show(need: .change)
        model.closeSheet(moving: true)
        XCTAssertEqual(model.transition.phase, .closing)
        let told = tracking(sheet)

        release()
        try await wait("the second print") { self.printed(2) }
        await settle()

        XCTAssertEqual(told.count, 0)
        ends()
        try await wait("the held rows") { sheet.list.shown.map(\.title) == ["A2"] }
    }

    func testWhatAnotherSpotPrintsWhileASheetClosesIsNotHeld() async throws {
        let sheet = try await openOnce()
        try script("other", toml: "[on]\n\"panel.open\" = true", "printf 'item=o\\ntitle=O\\n'")
        await model.reload()
        host.heldEnds = []
        model.closeSheet(moving: true)
        XCTAssertEqual(model.transition.phase, .closing)

        let other = try XCTUnwrap(model.sheets["other"])
        other.show(need: .change)

        try await wait("the other rows") { other.list.shown.map(\.title) == ["O"] }
        XCTAssertEqual(sheet.list.shown.map(\.title), ["A1"])
        ends()
    }
}
