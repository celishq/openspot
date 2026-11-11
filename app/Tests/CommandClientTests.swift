import XCTest
@testable import OpenspotCore

/// Proves `Contents/Helpers/openspot`: it asks the socket of the running app, and starts the program of its app with the
/// same arguments when no socket answers or the call runs in a process of its own.
final class CommandClientTests: XCTestCase {
    private struct Host: CommandHost {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

    private var folder: URL!
    private var socket: CommandSocket?

    private var config: URL { folder.appendingPathComponent("config") }
    private var client: URL { folder.appendingPathComponent("A.app/Contents/Helpers/openspot") }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("oc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("A.app/Contents/MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        let built = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot")
        try FileManager.default.copyItem(at: built, to: client)
        try "#!/bin/sh\necho \"app: $*\"\n".writeScript(to: folder.appendingPathComponent("A.app/Contents/MacOS/Openspot"))
    }

    override func tearDownWithError() throws {
        socket?.close()
        try? FileManager.default.removeItem(at: folder)
    }

    private func listen() {
        socket = CommandSocket(folder: config, api: CommandAPI(host: Host()))
    }

    /// Runs the program with the arguments and stdin, and returns what it prints and its exit code.
    private func run(_ program: URL, _ arguments: [String], input: String = "") throws -> (output: String, errors: String, code: Int32) {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        let stdin = Pipe()
        process.executableURL = program
        process.arguments = arguments
        process.environment = ["OPENSPOT_CONFIG": config.path, "PATH": "/usr/bin:/bin"]
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = stdin
        try process.run()
        stdin.fileHandleForWriting.write(Data(input.utf8))
        try stdin.fileHandleForWriting.close()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let said = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return (printed, said, process.terminationStatus)
    }

    func testTheRunningAppAnswersACalcSum() throws {
        listen()

        let answer = try run(client, ["calc", "solve", "2+2"])

        XCTAssertEqual(TextBlock.blocks(in: answer.output).first?.value("title"), "4")
        XCTAssertEqual(answer.code, 0)
    }

    func testStdinStderrAndTheCodeComeThroughTheSocket() throws {
        listen()

        XCTAssertEqual(try run(client, ["check", "--sheet"], input: "title=Hi\n").output, "the sheet has no parts\n1 faults.\n")
        XCTAssertEqual(try run(client, ["check", "--sheet"], input: "title=Hi\n").code, 1)
        let unknown = try run(client, ["calc", "2+2"])
        XCTAssertTrue(unknown.errors.hasPrefix("openspot cannot do this: calc 2+2\n"))
        XCTAssertEqual(unknown.code, 2)
    }

    func testWithNoSocketItStartsTheAppWithTheSameArguments() throws {
        XCTAssertEqual(try run(client, ["guide"]).output, "app: guide\n")
    }

    func testACallThatRunsAloneStartsTheApp() throws {
        listen()

        XCTAssertEqual(try run(client, ["color", "pick"]).output, "app: color pick\n")
    }

    func testThroughALinkItStartsTheAppOfItsResolvedPath() throws {
        let link = folder.appendingPathComponent("openspot")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: client)

        XCTAssertEqual(try run(link, ["spot", "new", "x"]).output, "app: spot new x\n")
    }
}
