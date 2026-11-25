import XCTest
@testable import OpenspotCore

final class AttachmentSpotTests: BuiltInCase {
    private var attachments: Spot {
        get throws {
            try spot("attachments")
        }
    }

    private func items() async throws -> [SpotItem] {
        try await attachments.items(timeout: 60).items.filter { $0.section == nil }
    }

    private func access() async throws -> [SpotItem] {
        try await attachments.items(timeout: 60).items.filter { $0.section == "Access" }
    }

    private func press(_ handler: String, on item: String) async throws {
        try await attachments.perform(handler, input: "input.item=\(item)\n", timeout: 60)
    }

    private func press(_ row: SpotItem) async throws {
        let keys = row.fields.map { "input.item.\($0.key)=\($0.value)\n" }.joined()
        try await attachments.perform("press", input: "input.item=\(row.run)\n" + keys, timeout: 60)
    }

    private func opened() throws -> () -> [String] {
        let log = root.appendingPathComponent("opened")
        try fake("open", "echo \"$*\" >> '\(log.path)'")
        return { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
    }

    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("tab.spot/tab.sh"), toml: "title = 'Tab'\ndetail = 'Hand the front tab to a spot'\nuses = ['attachment']")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("copy.spot/copy.sh"), toml: "title = 'Copy'\nuses = ['attachment', 'clipboard']")
    }

    func testTheSearchFindsItByTheWordsOfWhatItReads() throws {
        let spot = try attachments

        XCTAssertTrue(spot.isFound)
        XCTAssertTrue(spot.showsInSheet)
        XCTAssertTrue(["attachments", "tab", "selection", "clipboard"].allSatisfy(spot.keywords.contains))
    }

    func testTheSheetListsEachSourceWithWhatItReads() async throws {
        let items = try await items()

        XCTAssertEqual(items.map(\.run), ["copy", "tab"])
        XCTAssertEqual(items.map(\.openTitle), ["Open Settings", "Open Settings"])
        XCTAssertEqual(items.last?.subtitle, "Hand the front tab to a spot")
    }

    func testReturnOpensTheSettingsOfTheSource() async throws {
        try await press("press", on: "tab")

        let opened = await app.opened
        XCTAssertEqual(opened, ["settings tab"])
        XCTAssertEqual(file.read().arrangement.choices, [])
    }

    func testAccessListsEachReaderWithWhetherMacOSLetsOpenspotReadIt() async throws {
        reads.set(installed: ["com.apple.Safari", "com.google.Chrome"], access: ["com.apple.Safari": .allowed, "com.google.Chrome": .unknown, "com.apple.finder": .denied], trust: .unasked)

        let rows = try await access()

        XCTAssertEqual(rows.map(\.title), ["Safari", "Chrome", "Finder", "Selected text"])
        XCTAssertEqual(rows.map(\.subtitle), ["Allowed", "Open the app to check", "Not allowed", "Not asked"])
        XCTAssertEqual(rows.first?.picture, .file("/Applications/Safari.app"))
        XCTAssertEqual(rows.map(\.openTitle), ["Manage in System Settings", "Open Chrome", "Open System Settings", "Ask for access"])
        let faults = try await attachments.sheetFaults(timeout: 60)
        XCTAssertEqual(faults, [])
    }

    func testReturnOnAnAppNotAskedAsksMacOSForIt() async throws {
        reads.set(installed: ["com.google.Chrome"], access: ["com.google.Chrome": .unasked])
        let rows = try await access()
        let chrome = try XCTUnwrap(rows.first)

        try await press(chrome)

        XCTAssertTrue(reads.asks.contains("com.google.Chrome true"), reads.asks.joined(separator: ", "))
    }

    func testReturnOnSelectedTextNotAskedAsksForAccessibility() async throws {
        reads.set(trust: .unasked)
        let rows = try await access()
        let selection = try XCTUnwrap(rows.last)

        try await press(selection)

        XCTAssertTrue(reads.asks.contains("accessibility true"), reads.asks.joined(separator: ", "))
    }

    func testReturnOnAReaderNotAllowedOpensItsPaneOfSystemSettings() async throws {
        let opened = try opened()
        reads.set(access: ["com.apple.finder": .denied], trust: .denied)
        let rows = try await access()

        for row in rows { try await press(row) }

        XCTAssertEqual(opened(), [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ])
    }
}
