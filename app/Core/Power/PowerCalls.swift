import Foundation

struct PowerCalls {
    let mac: (any MacPower)?
    let output: CommandOutput

    func lidClosed() -> CommandAPI.Work {
        CommandAnswer.work { [mac, output] in
            let power = try Mac.part(mac, "power helper")
            try await power.holdLidClosed()
            output.print("on\n")
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(86_400))
            }
            await power.releaseLidClosed()
            return ""
        }
    }

    func readings(_ form: PrintForm) -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            try form.text(of: try PowerReadings(sample: try await Mac.part(mac, "power helper").sample()))
        }
    }
}
