import Foundation

struct Transaction: Identifiable, Hashable {
    let id: String
    let date: Date
    let description: String
    let amount: Double
    var category: TransactionCategory
    let type: TransactionType
    
    init(id: String = UUID().uuidString, date: Date, description: String, amount: Double, category: TransactionCategory = .uncategorized, type: TransactionType = .expense) {
        self.id = id
        self.date = date
        self.description = description
        self.amount = amount
        self.category = category
        self.type = type
    }
    
    static func predictCategory(from description: String) -> TransactionCategory {
        let description = description.lowercased()
        
        // More precise keywords for each category
        let categoryKeywords: [(TransactionCategory, [String])] = [
            (.groceries, ["grocery", "supermarket", "whole foods", "safeway", "kroger", "costco", "aldi", "trader joe"]),
            (.utilities, ["electric", "water", "gas bill", "internet", "wifi", "phone", "cell", "verizon", "at&t", "comcast", "xfinity", "spectrum", "utility", "power", "energy"]),
            (.entertainment, ["netflix", "spotify", "hulu", "disney", "cinema", "theater", "theatre", "concert", "steam", "xbox", "playstation", "climbing", "gym", "fitness", "recreation"]),
            (.transportation, ["uber", "lyft", "taxi", "bus", "train", "subway", "metro", "parking", "gas station", "shell", "chevron", "exxon", "bp"]),
            (.dining, ["restaurant", "cafe", "coffee shop", "starbucks", "dunkin", "fast food", "delivery"]),
            (.shopping, ["amazon", "target", "walmart", "best buy", "home depot", "lowes", "ikea", "macy", "nordstrom", "clothing", "retail"]),
            (.healthcare, ["doctor", "medical", "health", "dental", "dentist", "pharmacy", "cvs pharmacy", "walgreens pharmacy", "hospital", "clinic"]),
            (.housing, ["rent", "mortgage", "apartment", "house", "insurance", "property", "hoa"]),
            (.education, ["school", "college", "university", "tuition", "education", "learning"])
        ]
        
        // Check for exact matches first
        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { keyword in
                description.contains(keyword)
            }) {
                return category
            }
        }
        
        // Specific brand name matching - more precise
        if description.contains("mcdonald") || description.contains("kfc") ||
           description.contains("taco bell") || description.contains("chipotle") ||
           description.contains("wendy") || description.contains("burger king") ||
           description.contains("pizza hut") || description.contains("domino") ||
           description.contains("papa john") || description.contains("subway") && description.contains("restaurant") {
            return .dining
        }
        
        if description.contains("united airlines") || description.contains("american airlines") ||
           description.contains("delta") || description.contains("southwest") ||
           description.contains("jetblue") || description.contains("alaska air") {
            return .transportation
        }
        
        // Special exclusions
        if description.contains("payment") && (description.contains("credit") || description.contains("card")) {
            return .uncategorized
        }
        
        if description.contains("deposit") || description.contains("transfer") || description.contains("ach electronic") {
            return .uncategorized
        }
        
        return .uncategorized
    }
}

enum TransactionType: String, CaseIterable {
    case income = "Income"
    case expense = "Expense"
}

enum TransactionCategory: String, CaseIterable, Codable {
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
