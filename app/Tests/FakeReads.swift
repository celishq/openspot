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
    private var scriptsValue: [String] = []
    private var asksValue: [String] = []

    func set(front: String? = nil, installed: Set<String> = [], access: [String: ReadAccess] = [:], grant: ReadAccess = .allowed, trust: ReadAccess = .allowed,
             answers: [String: [String]] = [:], selected: String? = nil) {
        lock.withLock {
            frontValue = front.map { FrontApp(bundleID: $0, path: "/Applications/\($0.split(separator: ".").last ?? "").app") }
            installedValue = installed
            accessValue = access
            grantValue = grant
            trustValue = trust
            answersValue = answers
            selectedValue = selected
        }
    }

    var scripts: [String] { lock.withLock { scriptsValue } }
    var asks: [String] { lock.withLock { asksValue } }

    func front() async -> FrontApp? { lock.withLock { frontValue } }
    func place(of bundleID: String) -> String? {
        lock.withLock { installedValue.contains(bundleID) || bundleID == "com.apple.finder" ? "/Applications/\(bundleID.split(separator: ".").last?.capitalized ?? bundleID).app" : nil }
    }

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
}
