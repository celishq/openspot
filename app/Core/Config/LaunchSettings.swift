import Foundation

public struct LaunchSettings: Equatable, Sendable {
    public static let valued = ["--config": "OPENSPOT_CONFIG", "--spots": "OPENSPOT_SPOTS", "--core": "OPENSPOT_CORE", "--store": "OPENSPOT_STORE", "--motion-slow": "OPENSPOT_MOTION_SLOW"]
    public static let switches = ["--picture-on-screen": "OPENSPOT_PICTURE_ON_SCREEN"]
    private static let prefix = "OPENSPOT_"

    public let variables: [String: String]
    public let words: [String]
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
        names = Set(valued.values).union(switches.values)
    }

    public func environment(from inherited: [String: String], keepsCallData: Bool) -> [String: String] {
        inherited.filter { keepsCallData ? !names.contains($0.key) : !$0.key.hasPrefix(Self.prefix) }.merging(variables) { _, given in given }
    }

    public func apply(keepsCallData: Bool) {
        let inherited = ProcessInfo.processInfo.environment
        let wanted = environment(from: inherited, keepsCallData: keepsCallData)
        for name in inherited.keys where wanted[name] == nil { unsetenv(name) }
        for (name, value) in variables { setenv(name, value, 1) }
    }
}
