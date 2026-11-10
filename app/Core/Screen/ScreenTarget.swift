import Foundation

/// A source that is found on the screen: a display, a window, or an area in points from the top left of the main display.
public enum ScreenTarget: Equatable, Sendable {
    case display(UInt32)
    case window(UInt32)
    case area(CGRect)

    /// The target as one field: `display=<id>`, `window=<id>` or `area=<x> <y> <width> <height>`.
    var field: TextBlock.Field {
        switch self {
        case .display(let id): .init(key: "display", value: String(id))
        case .window(let id): .init(key: "window", value: String(id))
        case .area(let frame):
            .init(key: "area", value: [frame.minX, frame.minY, frame.width, frame.height].map { "\(Double($0))" }.joined(separator: " "))
        }
    }

    /// Reads the field of a target from a block, or returns nil when it has none.
    init?(block: TextBlock) {
        if let id = block.value("display").flatMap(UInt32.init) {
            self = .display(id)
        } else if let id = block.value("window").flatMap(UInt32.init) {
            self = .window(id)
        } else if let values = block.value("area")?.split(separator: " ").compactMap({ Double($0) }), values.count == 4 {
            self = .area(CGRect(x: values[0], y: values[1], width: values[2], height: values[3]))
        } else {
            return nil
        }
    }
}
