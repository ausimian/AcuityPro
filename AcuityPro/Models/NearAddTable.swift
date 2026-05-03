import Foundation

/// Standard age-based near addition values for presbyopia correction.
enum NearAddTable {

    /// Returns the recommended near addition in dioptres for a given age.
    static func nearAdd(forAge age: Int) -> Double {
        switch age {
        case ..<40:  return 0.00
        case 40...44: return 1.00
        case 45...49: return 1.50
        case 50...54: return 2.00
        case 55...59: return 2.25
        default:      return 2.50   // 60+
        }
    }

    /// Intermediate addition derived from near add by deducting 40%
    /// (per consultant optometrist guidance — desktop distance ≈ 1.67×
    /// reading distance).
    static func intermediateAdd(fromNearAdd nearAdd: Double) -> Double {
        nearAdd * 0.6
    }
}
