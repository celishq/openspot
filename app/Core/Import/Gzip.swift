import Foundation

enum Gzip {
    static let magic: [UInt8] = [0x1f, 0x8b, 0x08]
    static let limit = 512 * 1024 * 1024

    static func isGzip(_ data: Data) -> Bool {
        data.count >= 18 && Array(data.prefix(3)) == magic
    }

    static func unzip(_ data: Data) -> Data? {
        guard isGzip(data) else { return nil }
        let bytes = [UInt8](data)
        let flags = bytes[3]
        var at = 10
        if flags & 0x04 != 0 {
            guard at + 2 <= bytes.count else { return nil }
            at += 2 + Int(bytes[at]) + Int(bytes[at + 1]) << 8
        }
        for flag in [UInt8(0x08), 0x10] where flags & flag != 0 {
            guard let end = bytes[min(at, bytes.count)...].firstIndex(of: 0) else { return nil }
            at = end + 1
        }
        if flags & 0x02 != 0 { at += 2 }
        guard at < bytes.count - 8 else { return nil }
        let body = Data(bytes[at..<(bytes.count - 8)])
        guard let out = try? (body as NSData).decompressed(using: .zlib) as Data, out.count <= limit else { return nil }
        return out
    }

    static func zip(_ data: Data) -> Data? {
        guard let body = try? (data as NSData).compressed(using: .zlib) as Data else { return nil }
        var out = Data(magic + [0, 0, 0, 0, 0, 0, 0xff])
        out.append(body)
        out.append(contentsOf: [UInt8](repeating: 0, count: 4))
        let size = UInt32(truncatingIfNeeded: data.count).littleEndian
        withUnsafeBytes(of: size) { out.append(contentsOf: $0) }
        return out
    }
}
