import XCTest

extension XCTestCase {
    /// A new empty folder for one test, under the folder that `run.sh` made for this run.
    func emptyFolder() throws -> URL {
        let root = try XCTUnwrap(ProcessInfo.processInfo.environment["AGENTS_TESTS"], "Run these tests with tests/run.sh.")
        let folder = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Sets when a file last changed to so many seconds before now.
    func age(_ file: URL, by seconds: TimeInterval) throws {
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-seconds)], ofItemAtPath: file.path)
    }
}
