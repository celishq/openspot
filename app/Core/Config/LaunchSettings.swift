import Foundation

public struct LaunchSettings: Equatable, Sendable {
    public static let valued = ["--config": "OPENSPOT_CONFIG", "--spots": "OPENSPOT_SPOTS", "--core": "OPENSPOT_CORE", "--examples": "OPENSPOT_EXAMPLES", "--motion-slow": "OPENSPOT_MOTION_SLOW"]
    public static let switches = ["--picture-on-screen": "OPENSPOT_PICTURE_ON_SCREEN"]

    public let variables: [String: String]
    public let words: [String]
    public let flags: [String]
    private let names: Set<String>

    public init(arguments: [String], valued: [String: String] = Self.valued, switches: [String: String] = Self.switches) {
        var variables: [String: String] = [:]
        var rest = arguments[...]
        while let flag = rest.first {
            if let name = switches[flag] {
                variables[name] = "1"
                rest = rest.dropFirst()
            } else if let name = valued[flag], rest.count > 1 {
                variables[name] = rest[rest.index(after: rest.startIndex)]
                rest = rest.dropFirst(2)
            } else {
                break
            }
        }
        self.variables = variables
        words = Array(rest)
        flags = Array(arguments[..<rest.startIndex])
        names = Set(valued.values).union(switches.values)
    }

    public func environment(from inherited: [String: String]) -> [String: String] {
        inherited.filter { !names.contains($0.key) }.merging(variables) { _, given in given }
    }

    public func apply() {
        for name in names { unsetenv(name) }
        for (name, value) in variables { setenv(name, value, 1) }
    }
}
