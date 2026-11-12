import XCTest

/// Proves the images of the guide: each image under an example exists, and was drawn from that example as it is now, so
/// that a changed example needs `make docs-images` again.
final class GuideImageTests: XCTestCase {
    private let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Each image of the guide, with the sh example right above it.
    private func images() throws -> [(name: String, example: String)] {
        let guide = try String(contentsOf: repo.appendingPathComponent("GUIDE.md"), encoding: .utf8)
        var found: [(String, String)] = []
        var last = ""
        var example: String?
        for line in guide.components(separatedBy: "\n") {
            if line == "```sh" { example = ""; continue }
            if let text = example {
                if line == "```" { last = text; example = nil } else { example = text + line + "\n" }
                continue
            }
            if line.hasPrefix("!["), let start = line.range(of: "](docs/images/"), line.hasSuffix(".png)") {
                found.append((String(line[start.upperBound...].dropLast(5)), last))
                last = ""
            }
        }
        return found
    }

    func testEachImageOfTheGuideIsDrawnFromItsExampleAsItIsNow() throws {
        let images = try images()
        XCTAssertGreaterThan(images.count, 3)
        for (name, example) in images {
            let folder = repo.appendingPathComponent("docs/images")
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(name).png").path), name)
            let drawn = try? String(contentsOf: folder.appendingPathComponent("\(name).example"), encoding: .utf8)
            XCTAssertFalse(example.isEmpty, "\(name) has no sh example right above it")
            XCTAssertEqual(drawn, example, "\(name).png shows an older example. Run make docs-images.")
        }
    }
}
