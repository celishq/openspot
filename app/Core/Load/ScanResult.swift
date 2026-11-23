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
        files.flatMap(\.spots)
    }

    mutating func checkBoundEvents(also unloaded: [Spot]) {
        let declared = Dictionary((scripts + unloaded).map { ($0.id, $0.events.map(\.name)) }) { first, _ in first }
        files = files.compactMap { file in
            let spots = file.spots.filter { spot in
                guard let fault = spot.triggers.unheard(by: spot.name, through: spot.bindings, declared: declared) else { return true }
                refused.append(Refusal(file: file.id, reason: fault))
                return false
            }
            return spots.isEmpty ? nil : SpotFile(id: file.id, spots: spots)
        }
    }

    public func offered(_ keys: [GlobalKey]) -> [GlobalKey] {
        keys.filter { key in
            switch key.act {
            case .open, .float: scripts.contains { $0.id == key.spot }
            case .command(let command): scripts.contains { $0.id == key.spot && $0.offers.contains { $0.id == command } }
            }
        }
    }

    public mutating func addSettings(in config: ConfigFile, secrets: SecretStore, read: Config? = nil, defaults: SpotArrangement = SpotArrangement()) {
        let read = read ?? config.read()
        files = files.map { SpotFile(id: $0.id, spots: $0.spots.map { spot in
            spot.takingSettings(in: config, secrets: secrets, isWindow: defaults.isWindow(of: spot.id) ?? false).withIcon(read.setting(ReservedSetting.icon, of: spot.id))
        }) }
    }
}
