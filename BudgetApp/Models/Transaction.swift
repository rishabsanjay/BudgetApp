import Foundation

struct Transaction: Identifiable, Hashable {
    let id: String
    let date: Date
    let description: String
    let amount: Double
    var category: TransactionCategory
    let type: TransactionType
    var confidence: Double = 0.0
    
    init(id: String = UUID().uuidString, date: Date, description: String, amount: Double, category: TransactionCategory = .uncategorized, type: TransactionType = .expense) {
        self.id = id
        self.date = date
        self.description = description
        self.amount = amount
        let (predictedCategory, confidence) = Transaction.predictCategoryWithConfidence(from: description, amount: amount)
        self.category = category == .uncategorized ? predictedCategory : category
        self.type = type
        self.confidence = confidence
    }
    
    static func predictCategory(from description: String) -> TransactionCategory {
        let (category, _) = predictCategoryWithConfidence(from: description, amount: 0)
        return category
    }
    
    static func predictCategoryWithConfidence(from description: String, amount: Double) -> (TransactionCategory, Double) {
        let description = description.lowercased()
        
        // Stage 1: Handle special transaction types first (highest priority)
        if let (category, confidence) = handleSpecialTransactions(description: description) {
            return (category, confidence)
        }
        
        // Stage 2: Exact merchant name matching (high confidence)
        if let (category, confidence) = exactMerchantMatch(description: description) {
            return (category, confidence)
        }
        
        // Stage 3: Context-aware service matching (Uber, Amazon, etc.)
        if let (category, confidence) = contextAwareServiceMatch(description: description) {
            return (category, confidence)
        }
        
        // Stage 4: Enhanced keyword matching with patterns
        if let (category, confidence) = enhancedKeywordMatch(description: description) {
            return (category, confidence)
        }
        
        // Stage 5: Pattern-based analysis (transaction codes, amounts, etc.)
        if let (category, confidence) = patternBasedMatch(description: description, amount: amount) {
            return (category, confidence)
        }
        
        // Stage 6: Smart defaults based on amount ranges and common patterns
        if let (category, confidence) = smartDefaultMatch(description: description, amount: amount) {
            return (category, confidence)
        }
        
        return (.uncategorized, 0.0)
    }
    
    // MARK: - Categorization Methods
    
    private static func handleSpecialTransactions(description: String) -> (TransactionCategory, Double)? {
        // Venmo and peer-to-peer payments
        if description.contains("venmo") {
            return (.transfers, 0.98)
        }
        
        // Tutoring and education services
        if description.contains("tutoring") || description.contains("tutor") {
            return (.education, 0.95)
        }
        
        // Bank and financial transactions
        if description.contains("automatic payment") || description.contains("online payment") ||
           description.contains("ach electronic") || description.contains("direct deposit") ||
           description.contains("wire transfer") || description.contains("check deposit") {
            return (.uncategorized, 0.99) // Keep financial transactions uncategorized
        }
        
        // Specific Uber services (context matters!)
        if description.contains("uber") {
            if description.contains("eats") {
                return (.dining, 0.96)
            } else if description.contains("trip") {
                return (.transportation, 0.96)
            } else {
                // Default Uber to transportation unless context suggests otherwise
                return (.transportation, 0.85)
            }
        }
        
        // DoorDash and food delivery
        if description.contains("doordash") || description.contains("dd *doordash") {
            if description.contains("dashpass") {
                return (.entertainment, 0.90) // Subscription service
            } else {
                return (.dining, 0.95)
            }
        }
        
        // Specific educational institutions and services
        if description.contains("college") || description.contains("university") ||
           description.contains("middlesex cc") || description.contains("flywire") ||
           description.contains("chegg") {
            return (.education, 0.95)
        }
        
        // Car services and maintenance
        if description.contains("car wash") || description.contains("oil change") ||
           description.contains("auto repair") || description.contains("mechanic") {
            return (.transportation, 0.90)
        }
        
        // Parking and tolls
        if description.contains("parking") || description.contains("toll") ||
           description.contains("bridge") || description.contains("fastrak") {
            return (.transportation, 0.92)
        }
        
        return nil
    }
    
    private static func exactMerchantMatch(description: String) -> (TransactionCategory, Double)? {
        let exactMerchants: [(TransactionCategory, [String])] = [
            (.groceries, [
                "whole foods", "trader joe", "costco wholesale", "walmart supercenter",
                "target", "kroger", "safeway", "publix", "stop & shop", "giant food",
                "harris teeter", "wegmans", "heb", "meijer", "aldi", "food lion",
                "smith's food", "king soopers", "ralphs", "vons", "albertsons",
                "trinethra super market", "india cash & carry", "99 ranch"
            ]),
            (.dining, [
                "mcdonald's", "starbucks", "subway", "chipotle", "taco bell", "kfc",
                "burger king", "wendy's", "pizza hut", "domino's", "papa john's",
                "dunkin'", "olive garden", "applebee's", "chili's", "outback steakhouse",
                "panera bread", "five guys", "in-n-out", "shake shack", "sonic drive-in",
                "chick-fil-a", "panda express", "qdoba", "del taco", "tst*chaat bhavan",
                "coconut hill", "anjappar", "kovaicafe", "inchin's bamboo", "pf changs"
            ]),
            (.transportation, [
                "shell", "chevron", "exxon", "bp", "mobil", "texaco", "marathon",
                "speedway", "wawa", "sheetz", "delta air lines", "united airlines",
                "american airlines", "southwest airlines", "jetblue", "alaska airlines",
                "delta air", "vikhar valero", "gulf oil"
            ]),
            (.shopping, [
                "amazon", "amazon.com", "amzn mktp", "best buy", "home depot", "lowe's",
                "ikea", "macy's", "nordstrom", "tj maxx", "marshalls", "ross",
                "bed bath & beyond", "bath & body works", "victoria's secret",
                "old navy", "gap", "banana republic", "h&m", "zara", "uniqlo",
                "american eagle", "allsaints", "yves saint laurent"
            ]),
            (.entertainment, [
                "netflix", "spotify", "hulu", "disney+", "amazon prime", "apple music",
                "youtube premium", "amc theatres", "regal cinemas", "cinemark",
                "steam", "xbox", "playstation", "nintendo", "twitch", "paramount+",
                "prime video channels"
            ]),
            (.utilities, [
                "verizon", "at&t", "t-mobile", "sprint", "comcast", "xfinity",
                "spectrum", "cox communications", "directv", "dish network",
                "electric company", "gas company", "water authority", "waste management",
                "adt security"
            ]),
            (.healthcare, [
                "cvs pharmacy", "walgreens", "rite aid", "kaiser permanente",
                "blue cross", "aetna", "cigna", "humana", "united healthcare",
                "golden state dermatolo"
            ])
        ]
        
        for (category, merchants) in exactMerchants {
            for merchant in merchants {
                if description.contains(merchant) {
                    return (category, 0.95) // High confidence for exact matches
                }
            }
        }
        
        return nil
    }
    
    private static func contextAwareServiceMatch(description: String) -> (TransactionCategory, Double)? {
        // Amazon - context matters
        if description.contains("amazon") {
            if description.contains("prime video") || description.contains("prime membership") {
                return (.entertainment, 0.92)
            } else {
                return (.shopping, 0.90)
            }
        }
        
        // Apple services
        if description.contains("apple.com/bill") {
            // Could be App Store, iCloud, Apple Music, etc. - default to entertainment
            return (.entertainment, 0.85)
        }
        
        // Google/YouTube services
        if description.contains("google") || description.contains("youtube") {
            return (.entertainment, 0.88)
        }
        
        // Ride sharing vs food delivery
        if description.contains("lyft") {
            return (.transportation, 0.94)
        }
        
        // Specific food delivery context
        if description.contains("grubhub") || description.contains("postmates") ||
           description.contains("food delivery") || description.contains("otter*") {
            return (.dining, 0.92)
        }
        
        return nil
    }
    
    private static func enhancedKeywordMatch(description: String) -> (TransactionCategory, Double)? {
        let enhancedKeywords: [(TransactionCategory, [String], Double)] = [
            (.groceries, ["grocery", "supermarket", "market", "food store", "deli", "bakery", "butcher", "organic"], 0.85),
            (.utilities, ["electric", "electricity", "power", "water", "sewer", "gas bill", "internet", "wifi", "phone", "cell", "mobile", "cable", "fiber"], 0.88),
            (.entertainment, ["cinema", "theater", "theatre", "concert", "movie", "streaming", "subscription", "gym", "fitness", "club", "recreation", "sport"], 0.82),
            (.transportation, ["taxi", "rideshare", "bus", "train", "subway", "metro", "parking", "toll", "gas station", "fuel", "airline", "airport"], 0.80),
            (.dining, ["restaurant", "cafe", "coffee", "bar", "pub", "bistro", "grill", "diner", "fast food", "food delivery", "catering", "bakery"], 0.85),
            (.shopping, ["store", "shop", "retail", "mall", "outlet", "department", "clothing", "apparel", "electronics", "furniture", "online"], 0.75),
            (.healthcare, ["doctor", "medical", "health", "dental", "dentist", "pharmacy", "hospital", "clinic", "urgent care", "lab", "radiology"], 0.90),
            (.housing, ["rent", "mortgage", "property", "insurance", "maintenance", "repair", "cleaning", "landscaping", "hoa", "condo fee"], 0.92),
            (.education, ["school", "college", "university", "tuition", "education", "learning", "course", "training", "book", "supplies", "student"], 0.88)
        ]
        
        for (category, keywords, confidence) in enhancedKeywords {
            for keyword in keywords {
                if description.contains(keyword) {
                    return (category, confidence)
                }
            }
        }
        
        return nil
    }
    
    private static func patternBasedMatch(description: String, amount: Double) -> (TransactionCategory, Double)? {
        // Check for common transaction patterns
        
        // Subscription patterns (typically small, recurring amounts)
        if (5...50).contains(amount) && (description.contains("recurring") ||
                                        description.contains("subscription") ||
                                        description.contains("monthly") ||
                                        description.contains("auto pay")) {
            if description.contains("stream") || description.contains("music") || description.contains("video") {
                return (.entertainment, 0.70)
            } else {
                return (.utilities, 0.65)
            }
        }
        
        // ATM and banking patterns
        if description.contains("atm") || description.contains("withdrawal") ||
           description.contains("transfer") || description.contains("deposit") {
            return (.uncategorized, 0.95) // Keep these uncategorized
        }
        
        // Payment and credit patterns
        if description.contains("payment") && (description.contains("credit") || description.contains("card")) {
            return (.uncategorized, 0.95)
        }
        
        // Large amounts might be rent/mortgage
        if amount > 800 && (description.contains("payment") || description.contains("monthly")) {
            return (.housing, 0.60)
        }
        
        // TST* prefix usually indicates restaurants/food
        if description.hasPrefix("tst*") {
            return (.dining, 0.80)
        }
        
        // SQ * prefix usually indicates Square payment system (often food/retail)
        if description.hasPrefix("sq *") {
            if description.contains("coffee") || description.contains("food") {
                return (.dining, 0.75)
            } else {
                return (.shopping, 0.65)
            }
        }
        
        return nil
    }
    
    private static func smartDefaultMatch(description: String, amount: Double) -> (TransactionCategory, Double)? {
        // Very broad categorization based on amount patterns and common words
        
        // Large regular amounts (rent, mortgage, insurance)
        if amount > 500 {
            return (.housing, 0.30)
        }
        
        // Medium amounts (groceries, shopping)
        if (50...200).contains(amount) {
            if description.contains("store") || description.contains("market") {
                return (.groceries, 0.40)
            } else {
                return (.shopping, 0.35)
            }
        }
        
        // Small amounts (food, coffee, small purchases)
        if amount < 50 {
            if description.contains("food") || description.contains("cafe") || description.contains("coffee") {
                return (.dining, 0.45)
            } else {
                return (.shopping, 0.30)
            }
        }
        
        // If description contains location indicators
        if description.contains("#") || description.contains("store") || description.contains("location") {
            return (.shopping, 0.25)
        }
        
        return nil
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
    case transfers = "Transfers"
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
        case .transfers: return "arrow.left.arrow.right"
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
        case .transfers: return "indigo"
        case .uncategorized: return "gray"
        }
    }
}
