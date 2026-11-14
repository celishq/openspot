import Darwin
import MachO

struct AppBundle {
    private static let stateKey = "<key>OpenspotDevState</key>"

    let contents: String

    init?() {
        var size = UInt32(PATH_MAX)
        var path = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&path, &size) == 0, let real = realpath(path, nil) else { return nil }
        defer { free(real) }
        contents = Self.parent(of: Self.parent(of: String(cString: real)))
    }

    var program: String {
        contents + "/MacOS/Openspot"
    }

    var configFolder: String? {
        if let named = getenv("OPENSPOT_CONFIG").map({ String(cString: $0) }), !named.isEmpty { return named }
        if let state = devState, !state.isEmpty { return state }
        return getenv("HOME").map { String(cString: $0) + "/.config/openspot" }
    }

    private var devState: String? {
        guard let file = fopen(contents + "/Info.plist", "r") else { return nil }
        defer { fclose(file) }
        var bytes: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while case let count = fread(&buffer, 1, buffer.count, file), count > 0 { bytes += buffer[..<count] }
        let text = String(decoding: bytes, as: UTF8.self)
        guard let key = text.firstRange(of: Self.stateKey) else { return nil }
        let rest = text[key.upperBound...].drop { $0.isWhitespace }
        guard rest.hasPrefix("<string>"), let end = rest.firstRange(of: "</string>") else { return nil }
        return String(rest[rest.index(rest.startIndex, offsetBy: 8)..<end.lowerBound])
            .replacing("&lt;", with: "<").replacing("&gt;", with: ">").replacing("&quot;", with: "\"").replacing("&apos;", with: "'").replacing("&amp;", with: "&")
    }

    private static func parent(of path: String) -> String {
        String(path[..<(path.lastIndex(of: "/") ?? path.endIndex)])
    }
}
