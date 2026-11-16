import Foundation

public enum MotionTokens {
    public static let slow = Double(ProcessInfo.processInfo.environment["OPENSPOT_MOTION_SLOW"] ?? "") ?? 1

    public static let grow = 0.15 * slow
    public static let shrink = 0.2 * slow
    public static let move = 0.25 * slow
    public static let fadeIn = 0.1 * slow
    public static let fadeOut = 0.12 * slow
    public static let press = 0.2 * slow
    public static let pressBounce = 0.2

    public static let growSettle = 0.25 * slow
    public static let answerPause = 0.15

    public static let cardShare = 0.5
    public static let contentStart = 0.35

    public static let hiddenScale = 1.04
    public static let pressedScale = 1.04
    public static let liftedScale = 1.05
    public static let focusedScale = 1.04
    public static let pushedScale = 0.4
    public static let stepFadeWidth = 0.3
    public static let menuStartScale = 0.9
    public static let hiddenOpacity = 0.001
    public static let edgeScrollSpeed = 500.0

    public static let cardTurn = 12.0
    public static let cardLean = 9.0
    public static let cardPerspective = 0.6
    public static let cardFollow = 0.18
    public static let cardDrift = 0.05
    public static let cardSwaySpeed = (x: 0.6, y: 0.45)
    public static let cardSwayReach = (x: 0.5, y: 0.35)
}
