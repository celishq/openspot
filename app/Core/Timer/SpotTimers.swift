import Foundation

public struct SpotTimers: Equatable, Sendable {
    static let limit = 1000
    static let valueLimit = 4096

    public private(set) var list: [SpotTimer] = []
    let file: KeptFile<[SpotTimer]>

    init(file: URL?) {
        self.file = KeptFile(url: file)
    }

    mutating func read() {
        if let read = file.read(or: []) { list = read }
    }

    func write() {
        file.write(list)
    }

    var next: Date? {
        list.compactMap(\.at).min()
    }

    func of(_ spot: String) -> [SpotTimer] {
        list.filter { $0.spot == spot }.sorted { ($0.at ?? .distantFuture) < ($1.at ?? .distantFuture) }
    }

    mutating func add(_ timer: SpotTimer) -> String? {
        if (timer.inputs ?? []).reduce(0, { $0 + $1.name.utf8.count + $1.value.utf8.count }) > Self.valueLimit {
            return "A timer's value holds at most 4 KB."
        }
        if of(timer.spot).count >= Self.limit { return "A spot holds at most \(Self.limit) timers. Remove one with `openspot timer remove <id>`, then add again." }
        list.append(timer)
        return nil
    }

    mutating func remove(_ id: String, of spot: String) -> Bool {
        guard let index = list.firstIndex(where: { $0.id == id && $0.spot == spot }) else { return false }
        list.remove(at: index)
        return true
    }

    mutating func takeDue(at time: Date) -> [SpotTimer] {
        let due = list.filter { $0.at.map { $0 <= time } == true }
        if !due.isEmpty { list.removeAll { $0.at.map { $0 <= time } == true } }
        return due.sorted { ($0.at ?? .distantFuture) < ($1.at ?? .distantFuture) }
    }
}
