import Foundation

final class PowerLink: NSObject, PowerService, @unchecked Sendable {
    private let holds: PowerHolds

    init(holds: PowerHolds) {
        self.holds = holds
    }

    func holdLidClosed(reply: @escaping @Sendable (String?) -> Void) {
        reply(holds.hold(ObjectIdentifier(self)))
    }

    func releaseLidClosed(reply: @escaping @Sendable () -> Void) {
        holds.release(ObjectIdentifier(self))
        reply()
    }

    func sample(reply: @escaping @Sendable (Data?, String?) -> Void) {
        DispatchQueue.global().async {
            let arguments = ["-n", "1", "-i", "200", "--samplers", "cpu_power,gpu_power,thermal", "-f", "plist"]
            guard let data = PowerTool.run("/usr/bin/powermetrics", arguments) else {
                return reply(nil, "powermetrics did not give a sample.")
            }
            reply(data, nil)
        }
    }
}
