import XCTest
@testable import OpenspotCore

final class DocExampleTests: SampleSpotsCase {
    private let runnable: Set<String> = ["sh", "js", "swift"]

    private func docs() throws -> [RepoDoc] {
        try RepoDoc.all().filter { ["GUIDE.md", "PROTOCOL.md"].contains($0.path) || $0.path.hasPrefix("app/Help/") }
    }

    private func syntaxFault(of file: URL) throws -> String? {
        let check = Process()
        let errors = Pipe()
        check.executableURL = URL(fileURLWithPath: "/bin/sh")
        check.arguments = ["-n", file.path]
        check.standardError = errors
        try check.run()
        check.waitUntilExit()
        let text = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return check.terminationStatus == 0 ? nil : text
    }

    private func described(_ text: String, of language: String) throws -> TextBlock {
        try SpotToml(text: text, folder: "example.spot").block(of: "example.\(language)")
    }

    func testEachRunnableExampleOfTheDocsRunsInAFolderOfItsOwnWithTheManifestBeforeIt() async throws {
        try await withPrivateHome { home in
            var ran = 0
            for doc in try docs() {
                let fences = doc.fences
                for (index, fence) in fences.enumerated() where runnable.contains(fence.language) {
                    let place = "\(doc.path), example \(index + 1)"
                    let before = index > 0 && fences[index - 1].language == "toml" ? fences[index - 1].text : nil
                    if fence.language == "swift", !fence.text.hasPrefix("#!") {
                        let spot = fences[..<index].lastIndex { runnable.contains($0.language) && ($0.language != "swift" || $0.text.hasPrefix("#!")) }
                        let named = spot.flatMap { $0 > 0 && fences[$0 - 1].language == "toml" ? try? described(fences[$0 - 1].text, of: fences[$0].language) : nil }
                        XCTAssertNotNil(named?.value("view") ?? named?.value("source"), "\(place) is Swift that no view or source of the spot.toml before the example above it names. Make it a view or a source, or put it in a text fence.")
                        continue
                    }
                    let isSpot = fence.text.hasPrefix("#!") || fence.language == "js"
                    if !isSpot {
                        let lines = fence.text.split(separator: "\n").filter { !$0.isEmpty }
                        XCTAssertTrue(fence.language == "sh" && lines.allSatisfy { $0.hasPrefix("openspot ") }, "\(place) is neither a spot nor openspot commands. Put it in a text fence.")
                        continue
                    }
                    guard let before else {
                        XCTFail("\(place) is a spot with no toml fence of its spot.toml right before it.")
                        continue
                    }
                    let folder = home.appendingPathComponent("example-\(doc.path.replacingOccurrences(of: "/", with: "-"))-\(index)")
                    let file = folder.spotFile("example", extension: fence.language)
                    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try before.write(to: file.deletingLastPathComponent().appendingPathComponent(SpotToml.fileName), atomically: true, encoding: .utf8)
                    if fence.language == "js" {
                        try fence.text.write(to: file, atomically: true, encoding: .utf8)
                    } else {
                        try fence.text.writeScript(to: file)
                        if fence.language == "sh" { XCTAssertNil(try syntaxFault(of: file), place) }
                    }
                    let manifest = try described(before, of: fence.language)
                    let named = manifest.values("source")
                    let sources = named.isEmpty ? [] : fences[(index + 1)...].prefix { $0.language == "swift" && !$0.text.hasPrefix("#!") }
                    XCTAssertEqual(sources.count, named.count, "\(place) names \(named.count) sources, and \(sources.count) Swift examples follow it")
                    for (name, source) in zip(named, sources) {
                        try source.text.write(to: file.deletingLastPathComponent().appendingPathComponent(name), atomically: true, encoding: .utf8)
                    }
                    if let view = manifest.value("view") {
                        let source = fences[(index + 1)...].first { $0.language == "swift" }
                        XCTAssertNotNil(source, "\(place) names the view \(view), and no Swift example follows it")
                        try source?.text.write(to: file.deletingLastPathComponent().appendingPathComponent(view), atomically: true, encoding: .utf8)
                    }
                    let others = manifest.fields.filter { $0.key.hasPrefix("grid.") }.flatMap { $0.value.split(separator: " ").map(String.init) } + manifest.values("to")
                    for name in Set(others) {
                        let other = folder.spotFile(name)
                        try "#!/bin/sh\nprintf 'text=t\\ntitle=T\\n'\n".writeScript(to: other)
                        try "on = [\"clock.60\"]\n".write(to: other.deletingLastPathComponent().appendingPathComponent(SpotToml.fileName), atomically: true, encoding: .utf8)
                    }

                    let faults = await SpotCheck(folder: SpotsFolder(url: folder), views: ViewLibrary(cache: home.appendingPathComponent("views")), programs: SwiftProgram(cache: home.appendingPathComponent("programs")), environment: TestEnvironment.values).faults()
                    XCTAssertEqual(faults, [], place)

                    guard let spot = try SpotsFolder(url: folder).scan().spots.first(where: { $0.id == "example" }) else {
                        XCTFail("\(place) does not load")
                        continue
                    }
                    if spot.read == nil, spot.kind != .widget {
                        let calls = spot.offers.map(\.id) + spot.offeredActions.map(\.action.id)
                        for call in calls.isEmpty ? ["open"] : calls {
                            do {
                                try await spot.perform(SpotAction(arguments: [call]), timeout: 60)
                            } catch {
                                XCTFail("\(place) fails its call \(call): \(error)")
                            }
                        }
                    }
                    ran += 1
                }
            }
            XCTAssertGreaterThan(ran, 0)
        }
    }
}
