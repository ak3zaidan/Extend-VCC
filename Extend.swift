import Foundation

struct ExtendVCC: Identifiable, Hashable {
    var id: String
    var ccNum: String
    var ccMonth: String
    var ccYear: String
    var cvv: String
}

struct ExtendPassThrough {
    var fileName: String
    var sourceAccountId: String
    var accessToken: String
    var cardLimit: Int
    var email: String
    var dataArray: [String]
    var recurenceFrequency: RecurenceFrequency
    var shouldCreateNew: Bool
}

enum RecurenceFrequency: String {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
}

struct ExtendAccounts: Identifiable, Hashable {
    var id: String
    var displayName: String
    var companyName: String
    var photo: String
    var email: String
}

struct CreditCard: Codable {
    var id: String
    var displayName: String
    var companyName: String
    var user: ExtendUser
    var cardImage: CardImage
}

struct ExtendUser: Codable {
    var email: String
}

struct CardImage: Codable {
    var urls: ImageUrls
}

struct ImageUrls: Codable {
    var small: String
}

struct CreditCardsResponse: Codable {
    var creditCards: [CreditCard]
}
