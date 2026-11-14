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

    func testEachRunnableExampleOfTheDocsRunsInAFolderOfItsOwn() async throws {
        try await withPrivateHome { home in
            var ran = 0
            for doc in try docs() {
                let fences = doc.fences
                for (index, fence) in fences.enumerated() where runnable.contains(fence.language) {
                    let place = "\(doc.path), example \(index + 1)"
                    if fence.language == "swift" {
                        let named = fences[..<index].last { runnable.contains($0.language) }.map { SpotHeader(text: $0.text).block.value("view") } ?? nil
                        XCTAssertNotNil(named, "\(place) is Swift that no view= of the example before it names. Make it a view, or put it in a text fence.")
                        continue
                    }
                    let isSpot = fence.text.hasPrefix("#!") || fence.text.hasPrefix("//")
                    if !isSpot {
                        let lines = fence.text.split(separator: "\n").filter { !$0.isEmpty }
                        XCTAssertTrue(fence.language == "sh" && lines.allSatisfy { $0.hasPrefix("openspot ") }, "\(place) is neither a spot nor openspot commands. Put it in a text fence.")
                        continue
                    }
                    let folder = home.appendingPathComponent("example-\(doc.path.replacingOccurrences(of: "/", with: "-"))-\(index)")
                    let file = folder.spotFile("example", extension: fence.language)
                    if fence.language == "js" {
                        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try fence.text.write(to: file, atomically: true, encoding: .utf8)
                    } else {
                        try fence.text.writeScript(to: file)
                        XCTAssertNil(try syntaxFault(of: file), place)
                    }
                    let header = SpotHeader(text: fence.text).block
                    if let view = header.value("view") {
                        let source = fences[(index + 1)...].first { $0.language == "swift" }
                        XCTAssertNotNil(source, "\(place) names the view \(view), and no Swift example follows it")
                        try source?.text.write(to: file.deletingLastPathComponent().appendingPathComponent(view), atomically: true, encoding: .utf8)
                    }
                    let named = header.fields.filter { $0.key.hasPrefix("grid.") }.flatMap { $0.value.split(separator: " ").map(String.init) } + header.values("to")
                    for name in Set(named) {
                        try "#!/bin/sh\n# on=clock.60\nprintf 'text=t\\ntitle=T\\n'\n".writeScript(to: folder.spotFile(name))
                    }

                    let faults = await SpotCheck(folder: SpotsFolder(url: folder), views: ViewLibrary(cache: home.appendingPathComponent("views"))).faults()
                    XCTAssertEqual(faults, [], place)

                    guard let spot = try SpotsFolder(url: folder).scan().spots.first(where: { $0.id == "example" }) else {
                        XCTFail("\(place) does not load")
                        continue
                    }
                    if spot.read == nil, spot.kind != .widget {
                        let calls = spot.offers.map(\.id) + spot.offeredActions.map(\.action.id)
                        for call in calls.isEmpty ? ["open"] : calls {
                            do {
                                try await spot.perform(SpotAction(arguments: [call]), timeout: 10)
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
