import Foundation

/// Every number of the app's motions: how long each kind of motion takes, its bounce, and the sizes and strengths that a
/// moving thing passes through. Each motion is one of five kinds: grow, shrink, move, fade and press. `SpotMotion` turns
/// these into curves, and no other file names a duration.
public enum MotionTokens {
    /// How many times slower each motion runs, from `OPENSPOT_MOTION_SLOW`, so that a film can show each frame.
    public static let slow = Double(ProcessInfo.processInfo.environment["OPENSPOT_MOTION_SLOW"] ?? "") ?? 1

    /// A surface that grows out of its source, such as a sheet out of its card or the actions menu out of its item.
    public static let grow = 0.15 * slow
    /// The same surface going back into its source, on a curve that lands on it when the motion completes.
    public static let shrink = 0.2 * slow
    /// A thing that moves in place, such as a card in Edit Spots or a scroll that follows the selection.
    public static let move = 0.25 * slow
    /// A thing that shows or hides in place, such as the panel, a hint or a handle.
    public static let fadeIn = 0.1 * slow
    public static let fadeOut = 0.12 * slow
    /// The answer to a press, and a mark that arrives, with its bounce.
    public static let press = 0.2 * slow
    public static let pressBounce = 0.2

    /// How long a grow moves until it lies within a point of its end, which is later than its length.
    public static let growSettle = 0.25 * slow
    /// How long a sheet with no answer yet holds its grow for the first answer.
    public static let answerPause = 0.15

    /// The share of a grow, from its source, in which the source's own look, such as a card's fill, gives way to the
    /// grown surface's.
    public static let cardShare = 0.5

    /// How large the panel's surfaces are as they fade in and out, and its backdrop.
    public static let hiddenScale = 1.04
    public static let backdropHiddenScale = 1.02
    /// How large a card grows while pressed, lifted in Edit Spots, or in focus.
    public static let pressedScale = 1.04
    public static let liftedScale = 1.05
    public static let focusedScale = 1.04
    /// How far the content of a sheet starts from its place as the next sheet of a flow pushes in: the whole width of a sheet.
    public static let slideDistance = Double(SheetPlacement.width)
    /// How small a card gets as an open sheet pushes it out.
    public static let pushedScale = 0.4
    /// How much stronger the blur is under a pressed card.
    public static let pressedGlass = 1.5
    /// The share of its size that the actions menu grows from.
    public static let menuStartScale = 0.9
    /// How strong a part stays while it is hidden: too faint to see, but drawn, so that its return redraws nothing.
    public static let hiddenOpacity = 0.001
    /// How fast the grid scrolls, in points a second, under a lifted card that lies deep in the fade at one of its ends.
    public static let edgeScrollSpeed = 500.0
}
