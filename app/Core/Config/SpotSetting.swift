import Foundation

public struct SpotSetting: Hashable, Sendable {
    public let spot: String
    public let key: String
    public let value: String

    public init(spot: String, key: String, value: String) {
        self.spot = spot
        self.key = key
        self.value = value
    }

    var table: ConfigDocument.Table {
        ConfigDocument.Table("settings", [("spot", .string(spot)), ("key", .string(key)), ("value", .string(value))])
    }
}
