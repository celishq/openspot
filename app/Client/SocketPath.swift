import Darwin

enum SocketPath {
    static let name = "api.socket"

    static func of(config: String) -> String {
        let own = config + "/" + name
        guard own.utf8.count >= MemoryLayout.size(ofValue: sockaddr_un().sun_path) else { return own }
        return folder + "/" + hash(config) + ".socket"
    }

    static func address(of path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    static var folder: String {
        "/tmp/openspot-\(getuid())"
    }

    private static func hash(_ text: String) -> String {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value = value &* 0x100_0000_01b3
        }
        let digits = String(value, radix: 16)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }
}
