import XCTest
@testable import OpenspotCore

extension SampleSpotsCase {
    func swiftSpot(_ name: String, in folder: URL, standIns: [String: String] = [:]) async throws -> URL {
        let spot = store.appendingPathComponent("\(name).spot")
        let built = folder.appendingPathComponent("built")
        try FileManager.default.createDirectory(at: built, withIntermediateDirectories: true)
        let main = built.appendingPathComponent("main.swift")
        try FileManager.default.copyItem(at: spot.appendingPathComponent("\(name).swift"), to: main)
        let sources = spot.appendingPathComponent(name)
        var paths = [main.path]
        for file in try FileManager.default.contentsOfDirectory(atPath: sources.path).filter({ $0.hasSuffix(".swift") }).sorted() {
            guard let standIn = standIns[file] else {
                paths.append(sources.appendingPathComponent(file).path)
                continue
            }
            let copy = built.appendingPathComponent(file)
            try standIn.write(to: copy, atomically: true, encoding: .utf8)
            paths.append(copy.path)
        }
        let program = built.appendingPathComponent(name)
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-Onone", "-module-name", "Spot"] + paths + ["-o", program.path], limit: 300, base: TestEnvironment.values)
        return program
    }

    func typechecks(_ name: String) async throws {
        let spot = store.appendingPathComponent("\(name).spot")
        let folder = try temporaryFolder()
        let main = folder.appendingPathComponent("main.swift")
        try FileManager.default.copyItem(at: spot.appendingPathComponent("\(name).swift"), to: main)
        let sources = try FileManager.default.contentsOfDirectory(atPath: spot.appendingPathComponent(name).path).filter { $0.hasSuffix(".swift") }
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-typecheck", "-module-name", "Spot", main.path] + sources.map { spot.appendingPathComponent("\(name)/\($0)").path }, limit: 300, base: TestEnvironment.values)
    }

    func staying(_ program: URL, as name: String, home: URL, variables: [String: String] = [:]) -> ScriptProcess {
        ScriptProcess(url: program, name: store.appendingPathComponent("\(name).spot/\(name).swift").path, mode: .stays, variables: variables, base: ["PATH": "\(home.appendingPathComponent("tools").path):/usr/bin:/bin", "HOME": home.path])
    }

    func notes(in folder: URL) -> String {
        (try? String(contentsOf: folder.appendingPathComponent("notes"), encoding: .utf8)) ?? ""
    }

    static func note(to folder: URL) -> String {
        """
        func note(_ word: String) {
            let file = "\(folder.appendingPathComponent("notes").path)"
            let old = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
            try? (old + word + "\\n").write(toFile: file, atomically: true, encoding: .utf8)
        }
        """
    }
}
