import Foundation

struct TestClient: Sendable {
    let folder: URL

    var config: URL { folder.appendingPathComponent("config") }
    var program: URL { folder.appendingPathComponent("A.app/Contents/Helpers/openspot") }

    init(beside bundle: Bundle) throws {
        guard let temp = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileNoSuchFile) }
        defer { free(temp) }
        folder = URL(fileURLWithPath: String(cString: temp), isDirectory: true).appendingPathComponent("tc-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: program.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: bundle.bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: program)
    }

    func remove() {
        try? FileManager.default.removeItem(at: folder)
    }

    func start(_ arguments: [String], config: URL? = nil, in place: URL? = nil) throws -> (process: Process, input: Pipe, output: Pipe, errors: Pipe) {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = program
        process.arguments = arguments
        process.environment = ["OPENSPOT_CONFIG": (config ?? self.config).path, "PATH": "/usr/bin:/bin"]
        process.currentDirectoryURL = place ?? folder
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = input
        try process.run()
        return (process, input, output, errors)
    }

    func run(_ arguments: [String], input: String = "", config: URL? = nil, in place: URL? = nil) throws -> (output: String, errors: String, code: Int32) {
        let call = try start(arguments, config: config, in: place)
        call.input.fileHandleForWriting.write(Data(input.utf8))
        try call.input.fileHandleForWriting.close()
        let printed = String(decoding: call.output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let said = String(decoding: call.errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        call.process.waitUntilExit()
        return (printed, said, call.process.terminationStatus)
    }
}
