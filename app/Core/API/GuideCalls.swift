import Foundation

/// The call of `openspot guide`: the guide to building a spot.
struct GuideCalls {
    let mac: any Mac

    func text() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in
            guard let guide = mac.guide else { throw SpotError.fault("This copy of Openspot has no guide. Install Openspot again.") }
            return try String(contentsOf: guide, encoding: .utf8)
        }
    }
}
