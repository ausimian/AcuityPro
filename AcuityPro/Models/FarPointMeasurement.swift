import Foundation

/// The meridian in which a far-point measurement was taken.
enum MeridianType: Equatable {
    case sphere
    case cylinder(axisDegrees: Int)
}

/// A single far-point distance reading and its computed dioptric power.
struct FarPointMeasurement: Equatable {
    let distanceCm: Float
    let dioptres: Double
    let timestamp: Date
    let eye: Eye
    let meridian: MeridianType

    init(distanceCm: Float, eye: Eye, meridian: MeridianType, timestamp: Date = Date()) {
        self.distanceCm = distanceCm
        self.dioptres = distanceCm > 0 ? -(100.0 / Double(distanceCm)) : 0
        self.timestamp = timestamp
        self.eye = eye
        self.meridian = meridian
    }
}
