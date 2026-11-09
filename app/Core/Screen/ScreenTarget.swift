import Foundation

/// A source that is found on the screen: a display, a window, or an area in points from the top left of the main display.
public enum ScreenTarget: Equatable, Sendable {
    case display(UInt32)
    case window(UInt32)
    case area(CGRect)
}
