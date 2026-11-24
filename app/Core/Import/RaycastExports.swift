import Foundation
import Synchronization

final class RaycastExports: Sendable {
    static let shared = RaycastExports()

    private let kept = Mutex<(stamp: String, export: RaycastExport)?>(nil)

    func keep(_ export: RaycastExport, of file: URL) {
        guard let stamp = Self.stamp(of: file) else { return }
        kept.withLock { $0 = (stamp, export) }
    }

    func export(of file: URL) -> RaycastExport? {
        guard let stamp = Self.stamp(of: file) else { return nil }
        return kept.withLock { $0?.stamp == stamp ? $0?.export : nil }
    }

    private static func stamp(of file: URL) -> String? {
        guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let date = values.contentModificationDate else { return nil }
        return "\(file.standardizedFileURL.path)\n\(date.timeIntervalSince1970)\n\(values.fileSize ?? 0)"
    }
}
