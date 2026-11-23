@testable import OpenspotCore

extension NumberReading {
    static func of(_ lines: String) -> NumberReading {
        NumberReading(block: TextBlock.blocks(in: "number=n\n" + lines)[0])
    }

    static func series(_ lines: String) -> NumberReading {
        NumberReading(block: TextBlock.blocks(in: "series=n\n" + lines)[0])
    }
}
