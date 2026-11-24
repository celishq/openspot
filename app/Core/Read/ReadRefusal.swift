import Foundation

struct ReadRefusal: LocalizedError, Equatable {
    private static let start = "Openspot can't read "
    private static let allow = ". Allow it in the Attachments spot."

    let reader: String

    var errorDescription: String? {
        Self.start + reader + Self.allow
    }

    static func field(of line: String) -> String? {
        guard let end = line.range(of: allow), let start = line[..<end.lowerBound].range(of: start, options: .backwards) else { return nil }
        return line[start.lowerBound..<end.lowerBound] + " · ⏎ Allow"
    }
}
