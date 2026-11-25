import XCTest

extension XCTestCase {
    func lines(at path: String) -> [String] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8), let end = text.lastIndex(of: "\n") else { return [] }
        return text[..<end].components(separatedBy: "\n")
    }

    func placed(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
