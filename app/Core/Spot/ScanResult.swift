public struct ScanResult: Equatable, Sendable {
    public struct Refusal: Equatable, Sendable {
        public let file: String
        public let reason: String

        public init(file: String, reason: String) {
            self.file = file
            self.reason = reason
        }
    }

    public var files: [SpotFile]
    public var refused: [Refusal]

    public init(files: [SpotFile], refused: [Refusal]) {
        self.files = files
        self.refused = refused
    }

    public var spots: [Spot] {
        files.flatMap(\.spots).enumerated()
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
    }

    public var scripts: [Spot] {
        files.flatMap(\.spots).filter { $0.kind != .widget }
    }

    public func offered(_ keys: [GlobalKey]) -> [GlobalKey] {
        keys.filter { key in
            switch key.act {
            case .float: scripts.contains { $0.id == key.spot && $0.offersFloat }
            case .command(let command): scripts.contains { $0.id == key.spot && $0.offers.contains { $0.id == command } }
            }
        }
    }

    public mutating func listKeys(in config: ConfigFile) {
        let read = config.read()
        files = files.map { SpotFile(id: $0.id, spots: $0.spots.map { $0.listingKeys(in: config).withIcon(read.setting(ReservedSetting.icon, of: $0.id)) }) }
    }

    mutating func keepOpenedOffTheGrid() {
        let opened = Set(files.flatMap(\.spots).compactMap(\.opens))
        files = files.map { SpotFile(id: $0.id, spots: $0.spots.map { opened.contains($0.id) ? $0.offTheGrid() : $0 }) }
    }

    mutating func removeWidgetsWithLostParts() {
        let metrics = Set(scripts.filter { $0.read != nil }.map(\.id))
        let silent = Set(scripts.filter { $0.read == nil && $0.answers == nil }.map(\.id))
        let ids = Set(spots.map(\.id))
        files = files.map { file in
            let kept = file.spots.filter { command in
                guard command.kind == .widget else { return true }
                var reason = command.places.first { !metrics.contains($0) }.map { id in
                    silent.contains(id)
                        ? "\(command.name) names \(id), which has no on= line, so it never prints a value. Give \(id) an event, such as on=clock.60."
                        : "\(command.name) names no metric called \(id)"
                }
                if reason == nil, let opens = command.opens, !ids.contains(opens) {
                    reason = "\(command.name) opens no command called \(opens)"
                }
                if let reason { refused.append(Refusal(file: file.id, reason: reason)) }
                return reason == nil
            }
            return SpotFile(id: file.id, spots: kept)
        }
    }
}
