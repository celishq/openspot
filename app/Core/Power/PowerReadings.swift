import Foundation

struct PowerReadings: PrintedRecord, Equatable {
    let watts: Double
    let cpuWatts: Double
    let gpuWatts: Double
    let aneWatts: Double
    let thermalPressure: String

    private enum CodingKeys: String, CodingKey {
        case watts
        case cpuWatts = "cpu-watts"
        case gpuWatts = "gpu-watts"
        case aneWatts = "ane-watts"
        case thermalPressure = "thermal-pressure"
    }

    init(sample: Data) throws {
        let plist = sample.prefix { $0 != 0 }
        guard let root = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
              let processor = root["processor"] as? [String: Any] else {
            throw SpotError.fault("powermetrics gave a sample that Openspot cannot read.")
        }
        let watts = { (key: String) in ((processor[key] as? NSNumber)?.doubleValue ?? 0) / 1000 }
        self.watts = watts("combined_power")
        cpuWatts = watts("cpu_power")
        gpuWatts = watts("gpu_power")
        aneWatts = watts("ane_power")
        thermalPressure = ((root["thermal_pressure"] as? String) ?? "unknown").lowercased()
    }

    var blocks: [[(String, String?)]] {
        let text = { (value: Double) in String(format: "%.2f", value) }
        return [[
            (CodingKeys.watts.rawValue, text(watts)), (CodingKeys.cpuWatts.rawValue, text(cpuWatts)), (CodingKeys.gpuWatts.rawValue, text(gpuWatts)),
            (CodingKeys.aneWatts.rawValue, text(aneWatts)), (CodingKeys.thermalPressure.rawValue, thermalPressure)
        ]]
    }
}
