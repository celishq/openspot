import Foundation

enum CalcUnit {
    private static var kinds: [Dimension.Type] {
        [UnitLength.self, UnitArea.self, UnitVolume.self, UnitMass.self, UnitTemperature.self, UnitSpeed.self, UnitDuration.self,
         UnitInformationStorage.self, UnitEnergy.self, UnitPressure.self, UnitAngle.self]
    }

    static func areAlike(_ one: Dimension, _ two: Dimension) -> Bool {
        kinds.contains { one.isKind(of: $0) && two.isKind(of: $0) }
    }

    static func named(_ name: String) -> Dimension? {
        switch name.lowercased().replacingOccurrences(of: " ", with: "") {
        case "mm", "millimeter", "millimeters", "millimetre", "millimetres": UnitLength.millimeters
        case "cm", "centimeter", "centimeters", "centimetre", "centimetres": UnitLength.centimeters
        case "m", "meter", "meters", "metre", "metres": UnitLength.meters
        case "km", "kilometer", "kilometers", "kilometre", "kilometres": UnitLength.kilometers
        case "in", "inch", "inches", "\"": UnitLength.inches
        case "ft", "foot", "feet", "'": UnitLength.feet
        case "yd", "yard", "yards": UnitLength.yards
        case "mi", "mile", "miles": UnitLength.miles
        case "nmi", "nauticalmile", "nauticalmiles": UnitLength.nauticalMiles
        case "m²", "sqm", "squaremeter", "squaremeters", "squaremetre", "squaremetres": UnitArea.squareMeters
        case "km²", "sqkm", "squarekilometer", "squarekilometers", "squarekilometre", "squarekilometres": UnitArea.squareKilometers
        case "ft²", "sqft", "squarefoot", "squarefeet": UnitArea.squareFeet
        case "mi²", "sqmi", "squaremile", "squaremiles": UnitArea.squareMiles
        case "ha", "hectare", "hectares": UnitArea.hectares
        case "ac", "acre", "acres": UnitArea.acres
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres": UnitVolume.milliliters
        case "l", "liter", "liters", "litre", "litres": UnitVolume.liters
        case "m³", "cubicmeter", "cubicmeters", "cubicmetre", "cubicmetres": UnitVolume.cubicMeters
        case "gal", "gallon", "gallons": UnitVolume.gallons
        case "qt", "quart", "quarts": UnitVolume.quarts
        case "pt", "pint", "pints": UnitVolume.pints
        case "cup", "cups": UnitVolume.cups
        case "floz", "fluidounce", "fluidounces": UnitVolume.fluidOunces
        case "tbsp", "tablespoon", "tablespoons": UnitVolume.tablespoons
        case "tsp", "teaspoon", "teaspoons": UnitVolume.teaspoons
        case "mg", "milligram", "milligrams": UnitMass.milligrams
        case "g", "gram", "grams": UnitMass.grams
        case "kg", "kilogram", "kilograms", "kilo", "kilos": UnitMass.kilograms
        case "t", "tonne", "tonnes": UnitMass.metricTons
        case "oz", "ounce", "ounces": UnitMass.ounces
        case "lb", "lbs", "pound", "pounds": UnitMass.pounds
        case "st", "stone", "stones": UnitMass.stones
        case "c", "°c", "celsius": UnitTemperature.celsius
        case "f", "°f", "fahrenheit": UnitTemperature.fahrenheit
        case "kelvin": UnitTemperature.kelvin
        case "m/s", "mps": UnitSpeed.metersPerSecond
        case "km/h", "kmh", "kph": UnitSpeed.kilometersPerHour
        case "mph", "mi/h": UnitSpeed.milesPerHour
        case "kn", "kt", "knot", "knots": UnitSpeed.knots
        case "ms", "millisecond", "milliseconds": UnitDuration.milliseconds
        case "s", "sec", "secs", "second", "seconds": UnitDuration.seconds
        case "min", "mins", "minute", "minutes": UnitDuration.minutes
        case "h", "hr", "hrs", "hour", "hours": UnitDuration.hours
        case "d", "day", "days": UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))
        case "wk", "week", "weeks": UnitDuration(symbol: "wk", converter: UnitConverterLinear(coefficient: 604_800))
        case "bit", "bits": UnitInformationStorage.bits
        case "b", "byte", "bytes": UnitInformationStorage.bytes
        case "kb", "kilobyte", "kilobytes": UnitInformationStorage.kilobytes
        case "mb", "megabyte", "megabytes": UnitInformationStorage.megabytes
        case "gb", "gigabyte", "gigabytes": UnitInformationStorage.gigabytes
        case "tb", "terabyte", "terabytes": UnitInformationStorage.terabytes
        case "kib", "kibibyte", "kibibytes": UnitInformationStorage.kibibytes
        case "mib", "mebibyte", "mebibytes": UnitInformationStorage.mebibytes
        case "gib", "gibibyte", "gibibytes": UnitInformationStorage.gibibytes
        case "j", "joule", "joules": UnitEnergy.joules
        case "kj", "kilojoule", "kilojoules": UnitEnergy.kilojoules
        case "cal", "calorie", "calories": UnitEnergy.calories
        case "kcal", "kilocalorie", "kilocalories": UnitEnergy.kilocalories
        case "kwh", "kilowatthour", "kilowatthours": UnitEnergy.kilowattHours
        case "pa", "pascal", "pascals": UnitPressure.newtonsPerMetersSquared
        case "hpa", "hectopascal", "hectopascals": UnitPressure.hectopascals
        case "kpa", "kilopascal", "kilopascals": UnitPressure.kilopascals
        case "bar", "bars": UnitPressure.bars
        case "psi": UnitPressure.poundsForcePerSquareInch
        case "atm", "atmosphere", "atmospheres": UnitPressure(symbol: "atm", converter: UnitConverterLinear(coefficient: 101_325))
        case "°", "deg", "degree", "degrees": UnitAngle.degrees
        case "rad", "radian", "radians": UnitAngle.radians
        default: nil
        }
    }
}
