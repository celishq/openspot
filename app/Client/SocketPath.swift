import Darwin

enum SocketPath {
    static let name = "api.socket"

    static func of(config: String) -> String {
        let own = config + "/" + name
        guard own.utf8.count >= MemoryLayout.size(ofValue: sockaddr_un().sun_path) else { return own }
        return folder + "/" + hash(config) + ".socket"
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
