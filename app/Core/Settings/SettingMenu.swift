public struct SettingMenu: Equatable, Sendable {
    public let spot: String
    public let key: String
    public let options: [SpotPart.Option]
    public let value: String?
    public let serial: Int
}
