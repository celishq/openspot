import CoreGraphics

public enum WindowSize: String, CaseIterable, Sendable {
    case settings

    public var size: CGSize {
        switch self {
        case .settings: SpotTokens.settingsWindowSize
        }
    }

    public var minSize: CGSize {
        switch self {
        case .settings: SpotTokens.settingsWindowMinSize
        }
    }
}
