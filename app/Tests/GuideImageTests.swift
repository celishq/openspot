import CoreGraphics
import ImageIO
import XCTest

final class GuideImageTests: XCTestCase {
    private let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func images() throws -> [(name: String, example: String)] {
        let guide = try String(contentsOf: repo.appendingPathComponent("GUIDE.md"), encoding: .utf8)
        var found: [(String, String)] = []
        var last = ""
        var example: String?
        for line in guide.components(separatedBy: "\n") {
            if line == "```sh" || line == "```js" { example = ""; continue }
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
            XCTAssertFalse(example.isEmpty, "\(name) has no sh or js example right above it")
            XCTAssertEqual(drawn, example, "\(name).png shows an older example. Run make docs-images.")
        }
    }

    private struct Pixels {
        let width: Int
        let height: Int
        private let bytes: [UInt8]

        init?(_ file: URL) {
            guard let source = CGImageSourceCreateWithURL(file as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
                  let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            guard let context = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            width = image.width
            height = image.height
            self.bytes = bytes
        }

        func light(_ x: Int, _ y: Int) -> Int {
            let at = (y * width + x) * 4
            return (Int(bytes[at]) * 299 + Int(bytes[at + 1]) * 587 + Int(bytes[at + 2]) * 114) / 1000
        }
    }

    private static let margin = 96
    private static let rimLevel = 8
    private static let lineLevel = 25

    private func pixels(of name: String) throws -> Pixels {
        try XCTUnwrap(Pixels(repo.appendingPathComponent("docs/images/\(name).png")), name)
    }

    func testTheCardOfDiskHasNoStraightLineAtItsSides() throws {
        let image = try pixels(of: "show-a-value")
        let middle = image.height / 2
        for row in [middle - 28, middle + 28] {
            for (edge, out) in [(Self.margin, -1), (image.width - Self.margin - 1, 1)] {
                let ground = image.light(edge + 8 * out, row)
                for column in [edge + out, edge, edge - out] {
                    XCTAssertLessThan(image.light(column, row) - ground, Self.lineLevel, "a bright column at x \(column), y \(row)")
                }
            }
        }
    }

    func testTheTopEdgeOfEachSurfaceHasTheDarkLineOfSystemGlassOverItsBody() throws {
        for name in try images().map(\.name) where name != "panel" {
            let image = try pixels(of: name)
            let centre = image.width / 2
            let line = (Self.margin - 3...Self.margin + 2).map { image.light(centre, $0) }.min() ?? 0
            let body = image.light(centre, Self.margin + 6)
            XCTAssertGreaterThanOrEqual(body - line, Self.rimLevel, "\(name).png has no edge of system glass on its top")
        }
    }
}
