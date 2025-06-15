import Foundation

struct Transaction: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let description: String
    let amount: Double
    var category: TransactionCategory
    let type: TransactionType
    
    init(id: UUID = UUID(), date: Date, description: String, amount: Double, category: TransactionCategory = .uncategorized, type: TransactionType = .expense) {
        self.id = id
        self.date = date
        self.description = description
        self.amount = amount
        self.category = category
        self.type = type
    }
    
    static func predictCategory(from description: String) -> TransactionCategory {
        let description = description.lowercased()
        
        // Common keywords for each category
        let categoryKeywords: [(TransactionCategory, [String])] = [
            (.groceries, ["grocery", "supermarket", "food", "market", "walmart", "trader", "whole foods", "safeway", "kroger", "costco", "aldi"]),
            (.utilities, ["electric", "water", "gas", "internet", "wifi", "phone", "bill", "utility", "utilities", "power", "energy"]),
            (.entertainment, ["movie", "netflix", "spotify", "hulu", "disney", "cinema", "theater", "concert", "game", "steam", "xbox", "playstation"]),
            (.transportation, ["uber", "lyft", "taxi", "bus", "train", "subway", "metro", "gas", "fuel", "parking", "transit", "transport"]),
            (.dining, ["restaurant", "cafe", "coffee", "starbucks", "mcdonald", "burger", "pizza", "sushi", "dining", "doordash", "grubhub", "ubereats"]),
            (.shopping, ["amazon", "target", "walmart", "store", "shop", "mall", "clothing", "fashion", "retail", "purchase"]),
            (.healthcare, ["doctor", "medical", "health", "dental", "pharmacy", "hospital", "clinic", "medicine", "healthcare"]),
            (.housing, ["rent", "mortgage", "apartment", "house", "housing", "maintenance", "repair", "insurance"]),
            (.education, ["school", "college", "university", "course", "class", "book", "tuition", "education", "learning", "training"])
        ]
        
        // Check each category's keywords
        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { description.contains($0) }) {
                return category
            }
        }
        
        return .uncategorized
    }
}

enum TransactionType: String, CaseIterable {
    case income = "Income"
    case expense = "Expense"
}

enum TransactionCategory: String, CaseIterable {
    case groceries = "Groceries"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case transportation = "Transportation"
    case dining = "Dining"
    case shopping = "Shopping"
    case healthcare = "Healthcare"
    case housing = "Housing"
    case education = "Education"
    case uncategorized = "Uncategorized"
    
    var icon: String {
        switch self {
        case .groceries: return "cart"
        case .utilities: return "bolt"
        case .entertainment: return "tv"
        case .transportation: return "car"
        case .dining: return "fork.knife"
        case .shopping: return "bag"
        case .healthcare: return "cross"
        case .housing: return "house"
        case .education: return "book"
        case .uncategorized: return "questionmark"
        }
    }
    
    var color: String {
        switch self {
        case .groceries: return "green"
        case .utilities: return "yellow"
        case .entertainment: return "purple"
        case .transportation: return "blue"
        case .dining: return "orange"
        case .shopping: return "pink"
        case .healthcare: return "red"
        case .housing: return "brown"
        case .education: return "cyan"
        case .uncategorized: return "gray"
        }
    }
}
