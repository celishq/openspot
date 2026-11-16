import Foundation

public struct Theme: Equatable, Sendable {
    public struct Look: Equatable, Sendable {
        public fileprivate(set) var glassTint = HexColor(red: 0, green: 0, blue: 0, alpha: 0)
    }

    public private(set) var dark = Look()
    public private(set) var light = Look()
    public private(set) var faults: [String] = []

    public init() {}

    public init(unreadable fault: String) {
        faults = [fault]
    }

    public init(text: String) {
        self.init()
        let document: ConfigDocument
        do {
            document = try ConfigDocument(text: text)
        } catch {
            faults = ["theme.toml: \((error as? SpotError)?.reason ?? String(describing: error))"]
            return
        }
        let looks: [String: WritableKeyPath<Theme, Look>] = ["dark": \.dark, "light": \.light]
        for key in document.values.keys.sorted() {
            let parts = key.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count == 2, let look = looks[parts[0]], parts[1] == "glass-tint" else {
                faults.append("theme.toml: \(key) is not a key of a theme.")
                continue
            }
            guard case .string(let text)? = document.values[key], let color = HexColor(text: text) else {
                faults.append("theme.toml: \(key) is a colour such as #00000099.")
                continue
            }
            self[keyPath: look].glassTint = color
        }
    }
}
