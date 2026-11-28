import Foundation

enum Repo {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let spotFolders = ["spots", "store", "examples"]
}
