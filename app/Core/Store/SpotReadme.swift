import Foundation

public enum SpotReadme {
    public static let name = "readme.md"
    static let fileExtension = "md"

    public static func url(beside file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(name)
    }

    public static func media(in line: String) -> (source: String, caption: String)? {
        guard line.hasPrefix("!["), line.hasSuffix(")"), let middle = line.range(of: "]("),
              !line[middle.upperBound...].dropLast().contains(")") else { return nil }
        return (String(line[middle.upperBound..<line.index(before: line.endIndex)]), String(line[line.index(line.startIndex, offsetBy: 2)..<middle.lowerBound]))
    }

    static func lines(at url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let folder = url.deletingLastPathComponent()
        return text.split(separator: "\n", omittingEmptySubsequences: false).dropLast(text.hasSuffix("\n") ? 1 : 0).map { line in
            let line = String(line)
            guard let media = media(in: line), !media.source.hasPrefix("/"), !WebPictures.isWeb(media.source) else { return line }
            return "![\(media.caption)](\(folder.appendingPathComponent(media.source).path))"
        }
    }

    static func shown(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            media(in: String(line)).map { "[\($0.caption.isEmpty ? URL(fileURLWithPath: $0.source).lastPathComponent : $0.caption)]" } ?? String(line)
        }.joined(separator: "\n")
    }
}
