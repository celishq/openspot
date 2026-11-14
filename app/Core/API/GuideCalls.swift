import Foundation

struct GuideCalls {
    let mac: any Mac

    func text() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard let guide = mac.guide else { throw SpotError.fault("This copy of Openspot has no guide. Install Openspot again.") }
            return try String(contentsOf: guide, encoding: .utf8)
        }
    }
}
