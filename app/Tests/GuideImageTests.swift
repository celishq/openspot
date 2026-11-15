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
    private static let rimLevel = 40
    private static let lineLevel = 25

    private func pixels(of name: String) throws -> Pixels {
        try XCTUnwrap(Pixels(repo.appendingPathComponent("docs/images/\(name).png")), name)
    }

    func testTheCardOfDiskHasNoStraightLineAtItsSides() throws {
        let image = try pixels(of: "show-a-value")
        let middle = image.height / 2
        XCTAssertGreaterThanOrEqual(image.light(Self.margin + 8, middle) - image.light(Self.margin - 8, middle), Self.lineLevel, "the picture holds no card")
        for row in [middle - 28, middle + 28] {
            for (edge, out) in [(Self.margin, -1), (image.width - Self.margin - 1, 1)] {
                let ground = image.light(edge + 8 * out, row)
                for column in [edge + out, edge, edge - out] {
                    XCTAssertLessThan(image.light(column, row) - ground, Self.lineLevel, "a bright column at x \(column), y \(row)")
                }
            }
        }
    }

    func testTheTopEdgeOfEachSurfaceHasTheBrightRimOfFocusedGlassOverItsBody() throws {
        for name in try images().map(\.name) where name != "panel" {
            let image = try pixels(of: name)
            let centre = image.width / 2
            let rim = (Self.margin...Self.margin + 3).map { image.light(centre, $0) }.max() ?? 0
            let body = image.light(centre, Self.margin + 12)
            XCTAssertGreaterThanOrEqual(rim - body, Self.rimLevel, "\(name).png has no rim of focused glass on its top")
        }
    }

    private static let panelRims = [(name: "field", x: 469, y: 180), (name: "first card", x: 469, y: 332), (name: "round card", x: 244, y: 940), (name: "pill", x: 469, y: 1092)]
    private static let ridgeRows = 150...600
    private static let softLevel = 4

    func testThePanelShowsTheRimOfTheFieldTheCardsAndThePill() throws {
        let image = try pixels(of: "panel")
        for place in Self.panelRims {
            let rim = (place.y...place.y + 3).map { image.light(place.x, $0) }.max() ?? 0
            XCTAssertGreaterThanOrEqual(rim - image.light(place.x, place.y + 12), Self.rimLevel, "the \(place.name) has no rim of focused glass on its top")
        }
    }

    func testThePanelsBackdropSoftensTheWallpaperBesideTheCardsAndNotAtThePicturesEdge() throws {
        let image = try pixels(of: "panel")
        let step = { (column: Int) in
            zip(Self.ridgeRows, Self.ridgeRows.dropFirst()).map { abs(image.light(column, $0) - image.light(column, $1)) }.max() ?? 0
        }
        XCTAssertGreaterThanOrEqual(step(10) - step(172), Self.softLevel, "the ridge of the wallpaper is as sharp beside the cards as at the edge")
    }
}
