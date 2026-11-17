import XCTest
@testable import OpenspotCore

final class ThemeStageTests: PanelCase {
    private var marker: URL {
        folder.appendingPathComponent("runs.txt")
    }

    private func runCount() -> Int {
        ((try? String(contentsOf: marker, encoding: .utf8)) ?? "").split(separator: "\n").count
    }

    func testAStageShowsTheFramesOfThePanelAndRunsNoSpot() async throws {
        try script("count", header: "title=Count\non=panel.open", """
        [ "$1" = read ] || exit 0
        echo run >> '\(marker.path)'
        printf 'text=n\\ntitle=Seven\\n'
        """)
        try script("unseen", header: "title=Unseen\non=sheet.open", "echo run >> '\(marker.path)'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        try await wait("the panel's frame of count") { self.model.sheets["count"]?.shownFrame != nil }
        try await wait("the end of the panel's read") { !self.model.runs.isReading }
        let runs = runCount()
        let stageHost = FakeHost()
        let stage = SpotsModel(host: stageHost, files: model.files, runs: SpotRuns(showing: model.runs.shownFrames))

        await stage.reload()
        stage.panelWillShow()
        stage.press("unseen")
        try await wait("the stage's frame of count") { stage.sheets["count"]?.shownFrame == self.model.sheets["count"]?.shownFrame }
        stage.quit()
        withExtendedLifetime(stageHost) {}

        XCTAssertEqual(runCount(), runs)
        XCTAssertEqual(runs, 1)
        XCTAssertEqual(stage.entry("count")?.state, model.entry("count")?.state)
    }
}
