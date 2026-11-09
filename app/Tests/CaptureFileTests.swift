import XCTest
@testable import OpenspotCore

final class CaptureFileTests: XCTestCase {
    private var folder: URL!
    private let moment = Date(timeIntervalSince1970: 1_794_298_867)
    private let zone = TimeZone(identifier: "Europe/Berlin")!

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("capture-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func file(_ path: String?, _ kind: CaptureFile.Kind) throws -> URL {
        try CaptureFile(path: path, kind: kind, folder: folder, current: folder, now: moment, timeZone: zone).url
    }

    func testNoPathNamesTheCaptureAsMacOSDoesInTheFolder() throws {
        XCTAssertEqual(try file(nil, .picture).lastPathComponent, "Screenshot 2026-11-10 at 09.21.07.png")
        XCTAssertEqual(try file(nil, .video).lastPathComponent, "Screen Recording 2026-11-10 at 09.21.07.mp4")
        XCTAssertEqual(try file(nil, .picture).deletingLastPathComponent().path, folder.path)
    }

    func testANameThatIsTakenGetsANumber() throws {
        FileManager.default.createFile(atPath: try file(nil, .picture).path, contents: Data())

        XCTAssertEqual(try file(nil, .picture).lastPathComponent, "Screenshot 2026-11-10 at 09.21.07 (2).png")
    }

    func testAPathIsKeptAndARelativeOneStartsInTheCurrentFolder() throws {
        XCTAssertEqual(try file("/tmp/a.jpg", .picture).path, "/tmp/a.jpg")
        XCTAssertEqual(try file("shots/a.heic", .picture).path, folder.appendingPathComponent("shots/a.heic").path)
        XCTAssertEqual(try file("talk.MOV", .video).lastPathComponent, "talk.MOV")
    }

    func testAnExtensionOfAnotherKindFailsWithTheOnesThatWork() {
        XCTAssertThrowsError(try file("a.gif", .picture)) {
            XCTAssertEqual(($0 as? PluginError)?.reason, "Openspot cannot write a picture as a.gif. Name a .png, .jpg or .heic file.")
        }
        XCTAssertThrowsError(try file("talk.png", .video)) {
            XCTAssertEqual(($0 as? PluginError)?.reason, "Openspot cannot write a video as talk.png. Name a .mp4 or .mov file.")
        }
    }

    func testTheCameraFileLiesBesideTheVideo() {
        XCTAssertEqual(CaptureFile.camera(beside: URL(fileURLWithPath: "/a/Talk.mp4")).path, "/a/Talk.camera.mov")
    }
}
