import Foundation

public enum SpotGesture: Equatable, Sendable {
    case move(SpotDrag)
    case size(SpotResize)

    public var drag: SpotDrag? {
        if case .move(let drag) = self { drag } else { nil }
    }

    public var resize: SpotResize? {
        if case .size(let resize) = self { resize } else { nil }
    }

    public var id: String {
        switch self {
        case .move(let drag): drag.id
        case .size(let resize): resize.id
        }
    }

    var grid: GridLayout {
        switch self {
        case .move(let drag): drag.grid
        case .size(let resize): resize.grid
        }
    }

    var layout: [SpotPlacement] {
        switch self {
        case .move(let drag): drag.layout
        case .size(let resize): resize.layout
        }
    }
}
