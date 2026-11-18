import Foundation

struct PowerReadings: PrintedRecord {
    let watts: [(key: String, value: Double)]
    let thermalPressure: String

    private static let pressureKey = "thermal-pressure"
    private static let sources = [("watts", "combined_power"), ("cpu-watts", "cpu_power"), ("gpu-watts", "gpu_power"), ("ane-watts", "ane_power")]

    init(sample: Data) throws {
        let plist = sample.prefix { $0 != 0 }
        guard let root = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
              let processor = root["processor"] as? [String: Any] else {
            throw SpotError.fault("powermetrics gave a sample that Openspot cannot read.")
        }
        watts = Self.sources.map { key, source in (key, ((processor[source] as? NSNumber)?.doubleValue ?? 0) / 1000) }
        thermalPressure = ((root["thermal_pressure"] as? String) ?? "unknown").lowercased()
    }

    var blocks: [[(String, String?)]] {
        [[("text", "power")] + watts.map { ($0.key, String(format: "%.2f", $0.value)) } + [(Self.pressureKey, thermalPressure)]]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        for (key, value) in watts { try container.encode(value, forKey: Key(key)) }
        try container.encode(thermalPressure, forKey: Key(Self.pressureKey))
    }

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
