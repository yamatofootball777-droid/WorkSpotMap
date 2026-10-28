import Foundation

struct FacilityProfile: Codable, Equatable {
    var name: String
    var menu: String = ""
    var hours: String = ""
    var memo: String = ""
}
