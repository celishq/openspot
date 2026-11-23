import Foundation

public struct SpotSchedule: Equatable, Sendable {
    let file: KeptFile<[String: Date]>
    private(set) var isRead = false
    private var last: [String: Date] = [:]

    init(file: URL?) {
        self.file = KeptFile(url: file)
    }

    mutating func read() {
        isRead = true
        if let read = file.read(or: [:]) { last = read }
    }

    func write() {
        file.write(last)
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
}
