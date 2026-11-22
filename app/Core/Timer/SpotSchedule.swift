import Foundation

public struct SpotSchedule: Equatable, Sendable {
    let file: URL?
    private(set) var isRead = false
    private var last: [String: Date] = [:]

    init(file: URL?) {
        self.file = file
    }

    mutating func read() {
        isRead = true
        guard let file, let data = try? Data(contentsOf: file) else { return }
        last = (try? Self.decoder.decode([String: Date].self, from: data)) ?? [:]
    }

    func write() {
        guard let file else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Self.encoder.encode(last).write(to: file, options: .atomic)
    }

    func last(_ line: CronLine, of spot: String) -> Date? {
        last[Self.key(line, of: spot)]
    }

    mutating func ran(_ line: CronLine, of spot: String, at time: Date) {
        last[Self.key(line, of: spot)] = time
    }

    mutating func keep(only kept: Set<String>) -> Bool {
        let before = last.count
        last = last.filter { kept.contains($0.key) }
        return last.count != before
    }

    static func key(_ line: CronLine, of spot: String) -> String {
        "\(spot) \(line.text)"
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
