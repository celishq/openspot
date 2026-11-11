import Darwin
import MachO

/// The app that holds this program, found from its resolved path: `<app>/Contents/Helpers/openspot`.
struct AppBundle {
    private static let stateKey = "<key>OpenspotDevState</key>"

    /// The `Contents` folder of the app.
    let contents: String

    /// The bundle of the running program, or nil when its path does not resolve.
    init?() {
        var size = UInt32(PATH_MAX)
        var path = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&path, &size) == 0, let real = realpath(path, nil) else { return nil }
        defer { free(real) }
        contents = Self.parent(of: Self.parent(of: String(cString: real)))
    }

    /// The program of the app, which does each call itself.
    var program: String {
        contents + "/MacOS/Openspot"
    }

    /// The config folder of the app, as `SpotFolder.config` finds it: `OPENSPOT_CONFIG`, then the folder of a Debug build
    /// in its Info.plist, then `~/.config/openspot`.
    var config: String? {
        if let named = getenv("OPENSPOT_CONFIG").map({ String(cString: $0) }), !named.isEmpty { return named }
        if let state = devState, !state.isEmpty { return state }
        return getenv("HOME").map { String(cString: $0) + "/.config/openspot" }
    }

    /// The value of `OpenspotDevState` in the Info.plist of the app, which the build writes as XML.
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
