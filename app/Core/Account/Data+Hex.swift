import Foundation

extension Data {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }

    init?(hex text: String) {
        guard text.count % 2 == 0 else { return nil }
        var data = Data()
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            guard let byte = UInt8(text[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
