import Foundation

/// The file of a capture: the path that the script named, or a new name in the folder of screenshots, as macOS names one (S7).
public struct CaptureFile: Sendable {
    public enum Kind: Sendable {
        case picture
        case video

        var extensions: [String] {
            switch self {
            case .picture: ["png", "jpg", "jpeg", "heic"]
            case .video: ["mp4", "mov"]
            }
        }

        fileprivate var title: String {
            switch self {
            case .picture: "Screenshot"
            case .video: "Screen Recording"
            }
        }

        fileprivate func fault(_ name: String) -> String {
            switch self {
            case .picture: "Openspot cannot write a picture as \(name). Name a .png, .jpg or .heic file."
            case .video: "Openspot cannot write a video as \(name). Name a .mp4 or .mov file."
            }
        }
    }

    public let url: URL

    /// A relative path starts in the current folder. With no path, the name has the time and, when it is taken, a number.
    public init(path: String?, kind: Kind, folder: URL, current: URL, now: Date = Date(), timeZone: TimeZone = .current) throws {
        guard let path else {
            url = Self.free(kind: kind, folder: folder, now: now, timeZone: timeZone)
            return
        }
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : current.appendingPathComponent(path)
        guard kind.extensions.contains(url.pathExtension.lowercased()) else { throw PluginError.fault(kind.fault(url.lastPathComponent)) }
        self.url = url
    }

    /// The camera's own file beside a video, such as `Talk.camera.mov` beside `Talk.mp4`.
    public static func camera(beside video: URL) -> URL {
        video.deletingPathExtension().appendingPathExtension("camera").appendingPathExtension("mov")
    }

    private static func free(kind: Kind, folder: URL, now: Date, timeZone: TimeZone) -> URL {
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = timeZone
        format.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let base = "\(kind.title) \(format.string(from: now))"
        let pathExtension = kind.extensions[0]
        var url = folder.appendingPathComponent("\(base).\(pathExtension)")
        var number = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) (\(number)).\(pathExtension)")
            number += 1
        }
        return url
    }
}
