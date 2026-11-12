import XCTest
@testable import OpenspotCore

/// Proves the letters of the spots: the person gives each one in Edit Spots, and a core spot takes its letter from the
/// default config, which the person's config overrides.
@MainActor
final class SpotLettersTests: XCTestCase {
    private static let deleteCode: UInt32 = 51

    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-letters-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: configFolder, withIntermediateDirectories: true)
        let standard = folder.appendingPathComponent("defaults.toml")
        try "[[spots]]\nid = \"notes\"\nletter = \"n\"\n".write(to: standard, atomically: true, encoding: .utf8)
        suite = "openspot-letters-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = TestHost()
        let files = SpotFiles(
            environment: ["OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CONFIG": configFolder.path],
            home: folder,
            defaults: defaults,
            defaultConfig: standard
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var plugins: URL {
        folder.appendingPathComponent("plugins", isDirectory: true)
    }

    private var configFolder: URL {
        folder.appendingPathComponent("config", isDirectory: true)
    }

    private var config: String {
        (try? String(contentsOf: configFolder.appendingPathComponent("config.toml"), encoding: .utf8)) ?? ""
    }

    private func script(_ name: String) throws {
        try "#!/bin/sh\n# title=\(name.capitalized)\n".writeScript(to: plugins.spotFile(name))
    }

    private func letter(of id: String) -> String? {
        model.entries.first { $0.id == id }.flatMap(model.chainLetter(of:))
    }

    private func code(_ name: String) throws -> UInt32 {
        try XCTUnwrap(CommandKey(name: name)).code
    }

    /// Starts to record the letter of a spot in Edit Spots.
    private func startLetter(of id: String) throws {
        model.beginEditing()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
        model.handleEditKey(ActionKey(name: "l"))
    }

    func testTheDefaultConfigGivesASpotItsLetter() throws {
        try script("notes")

        model.reload()

        XCTAssertEqual(letter(of: "notes"), "N")
        XCTAssertTrue(model.handleChain(code: try code("n"), modifiers: model.entryKey.modifiers))
    }

    func testThePersonsLetterWinsAndARemovedDefaultStaysRemoved() throws {
        try script("notes")
        try script("mail")
        try "[[spots]]\nid = \"notes\"\nletter = \"\"\n\n[[spots]]\nid = \"mail\"\nletter = \"m\"\n"
            .write(to: configFolder.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        model.reload()

        XCTAssertNil(letter(of: "notes"))
        XCTAssertEqual(letter(of: "mail"), "M")
    }

    func testEditSpotsRecordsALetterIntoTheConfig() throws {
        try script("mail")
        model.reload()

        try startLetter(of: "mail")
        XCTAssertNotNil(model.recording)
        XCTAssertTrue(model.hint.contains("Esc Cancel"))
        model.record(code: try code("m"), modifiers: [])

        XCTAssertNil(model.recording)
        XCTAssertEqual(letter(of: "mail"), "M")
        XCTAssertTrue(config.contains("letter = \"m\""), config)
    }

    func testALetterThatAnotherSpotHoldsMovesAndTheToastNamesThatSpot() throws {
        try script("notes")
        try script("mail")
        model.reload()

        try startLetter(of: "mail")
        model.record(code: try code("n"), modifiers: [])
        model.reload()

        XCTAssertEqual(letter(of: "mail"), "N")
        XCTAssertNil(letter(of: "notes"))
        XCTAssertEqual(host.notes.count, 1)
        XCTAssertTrue(host.notes.first?.contains("Notes") == true, host.notes.description)
    }

    func testDeleteRemovesTheLetterAndEscapeKeepsIt() throws {
        try script("notes")
        model.reload()

        try startLetter(of: "notes")
        model.stopRecording()
        XCTAssertEqual(letter(of: "notes"), "N")

        model.handleEditKey(ActionKey(name: "l"))
        model.record(code: Self.deleteCode, modifiers: [])
        model.reload()

        XCTAssertNil(letter(of: "notes"))
        XCTAssertTrue(config.contains("letter = \"\""), config)
    }

    func testAKeyThatIsNotALetterKeepsRecordingAndSaysWhy() throws {
        try script("mail")
        model.reload()

        try startLetter(of: "mail")
        model.record(code: try code("m"), modifiers: [.command])

        XCTAssertNotNil(model.recording)
        XCTAssertNil(letter(of: "mail"))
        XCTAssertEqual(host.notes.count, 1)
    }

    func testEditSpotsShowsTheLetters() throws {
        try script("notes")
        model.reload()
        XCTAssertFalse(model.showsChain)

        model.beginEditing()

        XCTAssertTrue(model.showsChain)
        XCTAssertEqual(letter(of: "notes"), "N")
    }

    func testTheEditHintNamesTheLetterKey() throws {
        try script("mail")
        model.reload()

        model.beginEditing()

        XCTAssertTrue(model.hint.contains("L Letter"), model.hint)
    }
}
