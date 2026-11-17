import Foundation
import OpenspotCore
import Security
import ServiceManagement

final class SpotPower: MacPower, @unchecked Sendable {
    static let shared = SpotPower()

    private static let loginItems = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    func holdLidClosed() async throws {
        let fault: String? = try await ask { service, reply in service.holdLidClosed { reply(.success($0)) } }
        if let fault { throw SpotError.fault(fault) }
    }

    func releaseLidClosed() async {
        let _: Void? = try? await ask(again: false) { service, reply in service.releaseLidClosed { reply(.success(())) } }
    }

    func sample() async throws -> Data {
        let answer: (Data?, String?) = try await ask { service, reply in service.sample { reply(.success(($0, $1))) } }
        guard let data = answer.0 else { throw SpotError.fault(answer.1 ?? "powermetrics did not give a sample.") }
        return data
    }

    private func ask<Answer: Sendable>(again: Bool = true, _ send: @escaping @Sendable (PowerService, @escaping @Sendable (Result<Answer, Error>) -> Void) -> Void) async throws -> Answer {
        do {
            return try await once(send)
        } catch {
            guard again else { throw error }
            try Self.ready()
            return try await once(send)
        }
    }

    private func once<Answer: Sendable>(_ send: @escaping @Sendable (PowerService, @escaping @Sendable (Result<Answer, Error>) -> Void) -> Void) async throws -> Answer {
        let connection = link()
        return try await withCheckedThrowingContinuation { continuation in
            let reply = PowerReply(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { reply.give(.failure($0)) }
            guard let service = proxy as? PowerService else {
                return reply.give(.failure(SpotError.fault("Openspot cannot reach its power helper.")))
            }
            send(service, reply.give)
        }
    }

    private func link() -> NSXPCConnection {
        lock.withLock {
            if let connection { return connection }
            let connection = NSXPCConnection(machServiceName: PowerDaemon.label, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: PowerService.self)
            connection.setCodeSigningRequirement(PowerDaemon.helper)
            connection.invalidationHandler = { [weak self] in self?.forget() }
            connection.interruptionHandler = { [weak self] in self?.forget() }
            connection.resume()
            self.connection = connection
            return connection
        }
    }

    private func forget() {
        let gone = lock.withLock {
            defer { connection = nil }
            return connection
        }
        gone?.invalidate()
    }

    private static func ready() throws {
        guard isSignedByTeam() else {
            throw SpotError.fault("This build of Openspot is not signed by its team, so it cannot start its power helper. Use a release of Openspot.")
        }
        let daemon = SMAppService.daemon(plistName: PowerDaemon.plist)
        if daemon.status == .notRegistered || daemon.status == .notFound {
            do {
                try daemon.register()
            } catch {
                guard daemon.status == .requiresApproval else {
                    throw SpotError.fault("Openspot could not add its power helper: \(error.localizedDescription). Quit Openspot, open it again, then try again.")
                }
            }
        }
        switch daemon.status {
        case .enabled:
            return
        case .requiresApproval:
            SMAppService.openSystemSettingsLoginItems()
            throw SpotError.failedWithFix(1, "Openspot needs your approval for its power helper. Turn on Openspot in Login Items & Extensions, then try again.", loginItems)
        default:
            throw SpotError.fault("The power helper of Openspot did not answer. Run the call again, or restart the Mac if it keeps failing.")
        }
    }

    private static func isSignedByTeam() -> Bool {
        var code: SecCode?
        var requirement: SecRequirement?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(PowerDaemon.app as CFString, [], &requirement) == errSecSuccess, let requirement else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}
