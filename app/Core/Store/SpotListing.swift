import Foundation

public enum SpotListing {
    public static let readmeName = "readme.md"
    static let readmeExtension = "md"

    public static func readme(of file: URL) -> URL {
        file.deletingLastPathComponent().appendingPathComponent(readmeName)
    }
}
