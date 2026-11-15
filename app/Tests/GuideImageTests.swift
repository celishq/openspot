import XCTest

final class GuideImageTests: XCTestCase {
    private let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func images() throws -> [(name: String, example: String)] {
        let guide = try String(contentsOf: repo.appendingPathComponent("GUIDE.md"), encoding: .utf8)
        var found: [(String, String)] = []
        var last = ""
        var example: String?
        for line in guide.components(separatedBy: "\n") {
            if line == "```sh" || line == "```js" || line == "```swift" { example = ""; continue }
            if let text = example {
                if line != "```" {
                    example = text + line + "\n"
                    continue
                }
                if text.hasPrefix("#!") || text.hasPrefix("//") { last = text }
                example = nil
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
            XCTAssertFalse(example.isEmpty, "\(name) has no example of a spot right above it")
            XCTAssertEqual(drawn, example, "\(name).png shows an older example. Run make docs-images.")
        }
    }
}
