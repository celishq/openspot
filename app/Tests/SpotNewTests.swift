import XCTest
@testable import OpenspotCore

@MainActor
final class SpotNewTests: PanelCase {
    private func call(_ arguments: [String]) async throws -> CommandAnswer {
        let work = try XCTUnwrap(model.runs.api?.work(for: .test(arguments), input: { "" }))
        return await work()
    }

    private func drinks(addedDaysAgo old: [String: Double] = [:]) async throws {
        for (id, title) in ["coffee": "Coffee", "tea": "Tea"] {
            try script(id, toml: "title = '\(title)'", "printf 'item=a\\ntitle=A\\n'")
            let made = model.runs.now().addingTimeInterval(-(old[id] ?? 0.01) * 86_400)
            try FileManager.default.setAttributes([.creationDate: made], ofItemAtPath: spots.spotFile(id).path)
        }
        takeCalls()
        await model.reload()
    }

    private func isNew(_ id: String) -> Bool? {
        model.entries.first { $0.id == id }?.isNew
    }

    func testASpotOfYoursAddedThisWeekIsNewUntilYouOpenIt() async throws {
        try await drinks()
        XCTAssertEqual(isNew("tea"), true)
        model.isShown = true
        model.panelWillShow()

        model.tap("tea")

        try await wait("tea is no longer new") { self.isNew("tea") == false }
        XCTAssertEqual(isNew("coffee"), true)
        await model.reload()
        XCTAssertEqual(isNew("tea"), false)
    }

    func testASpotAddedOverAWeekAgoIsNotNew() async throws {
        try await drinks(addedDaysAgo: ["coffee": 8])

        XCTAssertEqual(isNew("coffee"), false)
        XCTAssertEqual(isNew("tea"), true)
    }

    func testASpotThatComesWithOpenspotIsNeverNew() async throws {
        try "printf 'item=a\\ntitle=A\\n'\n".writeScript(to: core.spotFile("milk"), toml: "title = 'Milk'")
        await model.reload()

        XCTAssertEqual(isNew("milk"), false)
    }

    func testASelectedNewSpotNamesEditInTheFooter() async throws {
        try await drinks(addedDaysAgo: ["coffee": 8])
        model.isShown = true
        model.panelWillShow()

        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "tea" })
        XCTAssertTrue(model.hint.contains("⌘E Edit"), model.hint)
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "coffee" })
        XCTAssertFalse(model.hint.contains("⌘E Edit"), model.hint)
    }

    func testTheFirstOpenOfANewSpotNamesEditInItsFooter() async throws {
        try await drinks()
        model.isShown = true
        model.panelWillShow()

        model.run(try XCTUnwrap(model.visible.first { $0.id == "tea" }))

        try await wait("the sheet") { self.model.openSheetID == "tea" }
        XCTAssertTrue(model.hint.contains("⌘E Edit"), model.hint)
    }

    func testNoCommandMarksASpot() async throws {
        try await drinks()

        let answer = try await call(["spot", "mark", "tea", "new"])

        XCTAssertNotEqual(answer.code, 0)
    }
}
