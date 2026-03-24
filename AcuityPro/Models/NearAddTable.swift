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

    /// Intermediate addition is 50% of the near addition.
    static func intermediateAdd(forAge age: Int) -> Double {
        nearAdd(forAge: age) * 0.5
    }
}
