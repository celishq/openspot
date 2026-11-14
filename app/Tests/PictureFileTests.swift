import XCTest
@testable import OpenspotCore

final class PictureFileTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-picture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func firstChange(of file: URL, writing write: @escaping @Sendable () throws -> Void) async throws -> Double?? {
        let changes = PictureFile(path: file.path).changes
        let next = Task { () -> Double?? in
            for await time in changes { return time }
            return nil
        }
        let writes = Task {
            while !Task.isCancelled {
                try write()
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        let limit = Task { try await Task.sleep(for: .seconds(10)); next.cancel() }
        let time = await next.value
        writes.cancel()
        limit.cancel()
        return time
    }

    func testAPictureThatAppearsAfterItsAnswerGivesItsTime() async throws {
        let file = folder.appendingPathComponent("cover.png")

        let time = try await firstChange(of: file) { try Data([1]).write(to: file, options: .atomic) }

        XCTAssertNotNil(try XCTUnwrap(time))
    }

    func testAPictureWrittenInPlaceGivesItsNewTime() async throws {
        let file = folder.appendingPathComponent("cover.png")
        try Data([1]).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: file.path)

        let time = try await firstChange(of: file) {
            let handle = try FileHandle(forWritingTo: file)
            try handle.write(contentsOf: Data([2, 3]))
            try handle.close()
        }

        let changed = try XCTUnwrap(try XCTUnwrap(time))
        XCTAssertGreaterThan(changed, 1_700_000_000)
    }
}
