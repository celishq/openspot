import Foundation

public enum ScreenTarget: Equatable, Sendable {
    case display(UInt32)
    case window(UInt32)
    case area(CGRect)

    var field: TextBlock.Field {
        switch self {
        case .display(let id): .init(key: "display", value: String(id))
        case .window(let id): .init(key: "window", value: String(id))
        case .area(let frame):
            .init(key: "area", value: [frame.minX, frame.minY, frame.width, frame.height].map { "\(Double($0))" }.joined(separator: " "))
        }
    }

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
