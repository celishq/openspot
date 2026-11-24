import Foundation
@testable import OpenspotCore

final class FakeReads: MacReads, @unchecked Sendable {
    private let lock = NSLock()
    private var frontValue: FrontApp?
    private var installedValue: Set<String> = []
    private var accessValue: [String: ReadAccess] = [:]
    private var grantValue: ReadAccess = .allowed
    private var trustValue: ReadAccess = .allowed
    private var answersValue: [String: [String]] = [:]
    private var selectedValue: String?
    private var countValue = 0
    private var copiedValue: String?
    private var scriptsValue: [String] = []
    private var asksValue: [String] = []

    func set(front: String? = nil, installed: Set<String> = [], access: [String: ReadAccess] = [:], grant: ReadAccess = .allowed, trust: ReadAccess = .allowed,
             answers: [String: [String]] = [:], selected: String? = nil) {
        lock.withLock {
            frontValue = front.map { FrontApp(bundleID: $0) }
            installedValue = installed
            accessValue = access
            grantValue = grant
            trustValue = trust
            answersValue = answers
            selectedValue = selected
        }
    }

    func copy(_ text: String?, count: Int) {
        lock.withLock {
            copiedValue = text
            countValue = count
        }
    }

    var scripts: [String] { lock.withLock { scriptsValue } }
    var asks: [String] { lock.withLock { asksValue } }

    func front() async -> FrontApp? { lock.withLock { frontValue } }
    func isInstalled(_ bundleID: String) -> Bool { lock.withLock { installedValue.contains(bundleID) } }

    func access(to bundleID: String, asks: Bool) async -> ReadAccess {
        lock.withLock {
            asksValue.append("\(bundleID) \(asks)")
            let access = accessValue[bundleID] ?? .allowed
            return access == .unasked && asks ? grantValue : access
        }
    }

    func run(_ script: String) async -> [String]? {
        lock.withLock {
            scriptsValue.append(script)
            return answersValue.first { script.contains($0.key) }?.value
        }
    }

    func accessibility(asks: Bool) -> ReadAccess {
        lock.withLock {
            asksValue.append("accessibility \(asks)")
            return trustValue == .unasked && asks ? grantValue : trustValue
        }
    }

    func selectedText() async -> String? { lock.withLock { selectedValue } }
    func copyCount() -> Int { lock.withLock { countValue } }
    func copiedText() -> String? { lock.withLock { copiedValue } }
}
