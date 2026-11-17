import Foundation

public enum MotionTokens {
    private static let launchSlow = Double(ProcessInfo.processInfo.environment["OPENSPOT_MOTION_SLOW"] ?? "") ?? 1
    nonisolated(unsafe) public private(set) static var slow = launchSlow
    public static let slowMotion = 10.0
    public static var isSlow: Bool {
        slow != launchSlow
    }

    @discardableResult
    public static func toggleSlowMotion() -> Bool {
        slow = slow == launchSlow ? launchSlow * slowMotion : launchSlow
        return slow != launchSlow
    }

    public static var grow: Double { SpotTokens.layout.motion.grow * slow }
    public static var shrink: Double { SpotTokens.layout.motion.shrink * slow }
    public static var move: Double { SpotTokens.layout.motion.move * slow }
    public static var fadeIn: Double { SpotTokens.layout.motion.fadeIn * slow }
    public static var fadeOut: Double { SpotTokens.layout.motion.fadeOut * slow }
    public static var press: Double { SpotTokens.layout.motion.press * slow }
    public static var pressBounce: Double { SpotTokens.layout.motion.pressBounce }
    public static let shrinkCurve = (x1: 0.2, y1: 0.1, x2: 0.2, y2: 1.0)

    public static var growSettle: Double { SpotTokens.layout.motion.settle * slow }
    public static let answerPause = 0.15

    public static let cardShare = 0.5
    public static let contentStart = 0.2

    public static let hiddenScale = 1.04
    public static var pressedScale: Double { SpotTokens.layout.motion.pressedScale }
    public static var liftedScale: Double { SpotTokens.layout.motion.liftedScale }
    public static var focusedScale: Double { SpotTokens.layout.motion.focusedScale }
    public static let pushedScale = 0.4
    public static let stepFadeWidth = 0.3
    public static let menuStartScale = 0.9
    public static let hiddenOpacity = 0.001
    public static let edgeScrollSpeed = 500.0
    public static let menuBarWorkScale = 0.72
    public static let menuBarSwapScale = 0.5

    public static let cardTurn = 12.0
    public static let cardLean = 9.0
    public static let cardPerspective = 0.6
    public static let cardFollow = 0.18
    public static let cardDrift = 0.05
    public static let cardSwaySpeed = (x: 0.6, y: 0.45)
    public static let cardSwayReach = (x: 0.5, y: 0.35)
}
