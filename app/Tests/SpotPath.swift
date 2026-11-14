import Foundation

extension URL {
    func spotFile(_ id: String, extension kind: String = "sh") -> URL {
        let parts = id.split(separator: "/").map(String.init)
        let name = parts.first ?? id
        return appendingPathComponent("\(name).spot", isDirectory: true).appendingPathComponent("\(parts.last ?? id).\(kind)")
    }
}

extension String {
    var inSpotFolder: String {
        let parts = split(separator: "/", maxSplits: 1).map(String.init)
        if parts.count > 1 { return parts[0].hasSuffix(".spot") ? self : "\(parts[0]).spot/\(parts[1])" }
        return "\(prefix { $0 != "." }).spot/\(self)"
    }
}
