import Darwin

/// Where the API socket of a config folder lies: `api.socket` in the folder, or a short path in `/tmp/openspot-<uid>` when
/// that one is too long for a socket address (S1). The app and the command find the same path from the folder's real path.
enum SocketPath {
    static let name = "api.socket"

    /// The path of the socket of the config folder at this real path.
    static func of(config: String) -> String {
        let own = config + "/" + name
        guard own.utf8.count >= MemoryLayout.size(ofValue: sockaddr_un().sun_path) else { return own }
        return folder + "/" + hash(config) + ".socket"
    }

    /// The folder of the short paths of this user.
    static var folder: String {
        "/tmp/openspot-\(getuid())"
    }

    /// The FNV-1a hash of the text, as 16 hex digits.
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
