import Foundation

/// What a press on the canvas does, in the order of the toolbar.
enum Tool: String, CaseIterable, Identifiable {
    case select, hand, pen, eraser, arrow, text, shape, bundle

    var id: String { rawValue }

    /// The symbol of the tool. The shape tool shows the form it draws instead.
    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .hand: "hand.raised"
        case .pen: "pencil.tip"
        case .eraser: "eraser"
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        case .shape: "square"
        case .bundle: "arrow.triangle.merge"
        }
    }

    var key: Character {
        switch self {
        case .select: "v"
        case .hand: "h"
        case .pen: "d"
        case .eraser: "e"
        case .arrow: "a"
        case .text: "t"
        case .shape: "r"
        case .bundle: "b"
        }
    }

    var title: String {
        switch self {
        case .select: "Select"
        case .hand: "Hand"
        case .pen: "Draw"
        case .eraser: "Eraser"
        case .arrow: "Arrow"
        case .text: "Text"
        case .shape: "Shape"
        case .bundle: "Tie arrows, or hold ⌥ and drag"
        }
    }

    /// Whether this tool draws a figure that takes the style.
    var draws: Bool {
        switch self {
        case .select, .hand, .eraser, .bundle: false
        default: true
        }
    }
}
