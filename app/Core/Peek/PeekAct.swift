import Foundation

public enum PeekAct: Equatable, Sendable {
    case copy(String)
    case paste(String)
    case open(String)

    static let runKey = "run"

    init?(block: TextBlock) {
        if let text = block.value("copy") {
            self = .copy(text)
        } else if let text = block.value("paste") {
            self = .paste(text)
        } else if let place = block.value("open") {
            self = .open(place)
        } else {
            return nil
        }
    }

    var name: String {
        switch self {
        case .copy: "copy"
        case .paste: "paste"
        case .open: "open"
        }
    }

    var url: URL? {
        guard case .open(let place) = self else { return nil }
        return place.hasPrefix("/") ? URL(fileURLWithPath: place) : URL(string: place)
    }

    var calls: [[String]] {
        switch self {
        case .copy: [["clipboard", "copy"]]
        case .paste: [["clipboard", "copy"], ["clipboard", "paste"]]
        case .open: []
        }
    }

    var input: String {
        switch self {
        case .copy(let text), .paste(let text), .open(let text): text
        }
    }

    static func actions(of blocks: [TextBlock]) -> [CommandAction] {
        blocks.dropFirst().compactMap { block in
            guard block.fields.first?.key == BlockKind.button.word, let title = block.value("title") else { return nil }
            if let act = PeekAct(block: block) { return .act(act, title: title) }
            return block.value(runKey).map { CommandAction(id: $0, title: title, scope: .item, after: .close) }
        }
    }
}
