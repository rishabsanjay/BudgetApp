import Foundation

@MainActor
class CategoryService: ObservableObject {
    private let apiKey: String? = nil // We'll implement free alternatives
    
    // MARK: - Enhanced Categorization with Multiple Strategies
    
    func enhanceTransactionCategorization(_ transactions: [Transaction]) async -> [Transaction] {
        var enhancedTransactions: [Transaction] = []
        
        for transaction in transactions {
            if transaction.category == .uncategorized || transaction.confidence < 0.5 {
                // Try additional categorization methods
                let enhancedTransaction = await categorizeTransaction(transaction)
                enhancedTransactions.append(enhancedTransaction)
            } else {
                enhancedTransactions.append(transaction)
            }
        }
        
        return enhancedTransactions
    }
    
    private func categorizeTransaction(_ transaction: Transaction) async -> Transaction {
        // Try merchant database lookup first
        if let category = await lookupMerchantDatabase(description: transaction.description) {
            return Transaction(
                id: transaction.id,
                date: transaction.date,
                description: transaction.description,
                amount: transaction.amount,
                category: category,
                type: transaction.type
            )
        }
        
        // Try pattern analysis
        if let category = analyzeTransactionPatterns(transaction) {
            return Transaction(
                id: transaction.id,
                date: transaction.date,
                description: transaction.description,
                amount: transaction.amount,
                category: category,
                type: transaction.type
            )
        }
        
        // If all else fails, use improved smart defaults
        let smartCategory = improvedSmartDefault(transaction)
        return Transaction(
            id: transaction.id,
            date: transaction.date,
            description: transaction.description,
            amount: transaction.amount,
            category: smartCategory,
            type: transaction.type
        )
    }
    
    // MARK: - Merchant Database Lookup
    
    private func lookupMerchantDatabase(description: String) async -> TransactionCategory? {
        // This would connect to a free merchant database API
        // For now, we'll implement a comprehensive local database
        
        let merchantDatabase = createComprehensiveMerchantDatabase()
        let cleanDescription = cleanMerchantName(description)
        
        // Try exact match first
        for (category, merchants) in merchantDatabase {
            if merchants.contains(where: { cleanDescription.contains($0) }) {
                return category
            }
        }
        
        // Try partial matches
        for (category, merchants) in merchantDatabase {
            for merchant in merchants {
                if cleanDescription.localizedCaseInsensitiveContains(merchant) || 
                   merchant.localizedCaseInsensitiveContains(cleanDescription) {
                    return category
                }
            }
        }
        
        return nil
    }
    
    private func createComprehensiveMerchantDatabase() -> [TransactionCategory: [String]] {
        return [
            .groceries: [
                // Major chains
                "whole foods", "trader joe", "costco", "walmart", "target", "kroger", "safeway",
                "publix", "stop shop", "giant", "harris teeter", "wegmans", "heb", "meijer",
                "aldi", "food lion", "smiths", "king soopers", "ralphs", "vons", "albertsons",
                "sprouts", "fresh market", "piggly wiggly", "winn dixie", "shoprite",
                
                // International
                "tesco", "sainsbury", "asda", "morrisons", "lidl", "carrefour", "metro",
                
                // Generic terms
                "supermarket", "grocery", "market", "food store", "organic", "fresh",
                "produce", "deli", "butcher", "bakery"
            ],
            
            .dining: [
                // Fast food
                "mcdonald", "burger king", "wendy", "taco bell", "kfc", "subway", "chipotle",
                "five guys", "shake shack", "in-n-out", "whataburger", "culver", "sonic",
                "arby", "popeyes", "chick-fil-a", "panda express", "qdoba", "del taco",
                
                // Coffee
                "starbucks", "dunkin", "costa coffee", "peet", "caribou coffee", "tim hortons",
                
                // Pizza
                "pizza hut", "domino", "papa john", "little caesars", "papa murphy",
                "casey", "godfather",
                
                // Casual dining
                "applebee", "chili", "olive garden", "red lobster", "outback", "tgi friday",
                "buffalo wild wings", "hooters", "ihop", "denny", "cracker barrel",
                "panera", "noodles company", "chipotle",
                
                // Generic terms
                "restaurant", "cafe", "coffee", "bar", "pub", "bistro", "grill", "diner",
                "eatery", "food delivery", "takeout", "catering", "brewery", "pizzeria"
            ],
            
            .transportation: [
                // Gas stations
                "shell", "exxon", "chevron", "bp", "mobil", "texaco", "marathon", "speedway",
                "circle k", "wawa", "sheetz", "7-eleven", "phillips 66", "conoco", "sunoco",
                
                // Airlines
                "delta", "united", "american airlines", "southwest", "jetblue", "alaska air",
                "frontier", "spirit", "allegiant",
                
                // Rideshare & taxi
                "uber", "lyft", "taxi", "cab", "rideshare",
                
                // Public transport
                "metro", "subway", "bus", "train", "transit", "mta", "bart", "cta",
                
                // Parking & tolls
                "parking", "park", "toll", "bridge", "tunnel",
                
                // Car services
                "auto", "mechanic", "repair", "oil change", "tire", "car wash",
                
                // Generic terms
                "transport", "travel", "fuel", "gas station", "service station"
            ],
            
            .shopping: [
                // Major retailers
                "amazon", "ebay", "walmart", "target", "best buy", "home depot", "lowe",
                "ikea", "macy", "nordstrom", "kohl", "jcpenney", "sear", "tj maxx",
                "marshalls", "ross", "nordstrom rack", "outlet",
                
                // Department stores
                "bloomingdale", "neiman marcus", "saks", "lord taylor", "dillard",
                
                // Clothing
                "h&m", "zara", "uniqlo", "forever 21", "old navy", "gap", "banana republic",
                "american eagle", "hollister", "abercrombie", "victoria secret",
                
                // Electronics
                "apple store", "microsoft store", "gamestop", "radio shack",
                
                // Home improvement
                "bed bath beyond", "williams sonoma", "pottery barn", "west elm",
                "restoration hardware", "world market",
                
                // Generic terms
                "store", "shop", "retail", "mall", "marketplace", "outlet", "boutique",
                "warehouse", "superstore"
            ],
            
            .entertainment: [
                // Streaming
                "netflix", "hulu", "disney", "amazon prime", "hbo", "showtime", "paramount",
                "peacock", "apple tv", "youtube premium",
                
                // Music
                "spotify", "apple music", "pandora", "tidal", "amazon music",
                
                // Gaming
                "steam", "xbox", "playstation", "nintendo", "epic games", "blizzard",
                "ea games", "ubisoft",
                
                // Movies
                "amc", "regal", "cinemark", "imax", "movie", "cinema", "theater",
                
                // Fitness
                "gym", "fitness", "planet fitness", "la fitness", "24 hour fitness",
                "equinox", "soul cycle", "yoga", "pilates",
                
                // Generic terms
                "entertainment", "recreation", "leisure", "hobby", "club", "subscription"
            ],
            
            .utilities: [
                // Telecom
                "verizon", "at&t", "t-mobile", "sprint", "metro pcs", "cricket", "boost mobile",
                
                // Internet/Cable
                "comcast", "xfinity", "spectrum", "cox", "optimum", "frontier", "centurylink",
                "directv", "dish network",
                
                // Utilities
                "electric", "electricity", "power", "energy", "gas", "water", "sewer",
                "waste management", "recycling", "trash",
                
                // Generic terms
                "utility", "bill", "service", "monthly service"
            ],
            
            .healthcare: [
                // Pharmacies
                "cvs", "walgreens", "rite aid", "pharmacy",
                
                // Insurance
                "blue cross", "aetna", "cigna", "humana", "united healthcare", "kaiser",
                
                // Medical
                "hospital", "clinic", "doctor", "physician", "medical", "health",
                "dental", "dentist", "orthodontist", "urgent care", "emergency",
                
                // Generic terms
                "healthcare", "medical center", "health system"
            ],
            
            .housing: [
                "rent", "mortgage", "property management", "apartment", "condo", "hoa",
                "homeowner association", "property tax", "insurance", "maintenance",
                "repair", "cleaning", "landscaping", "pest control",
                
                // Generic terms
                "housing", "real estate", "property"
            ],
            
            .education: [
                "school", "college", "university", "tuition", "education", "learning",
                "course", "training", "textbook", "supplies", "student", "academic",
                
                // Specific institutions would be added here based on common ones
                "community college", "state university"
            ]
        ]
    }
    
    private func cleanMerchantName(_ description: String) -> String {
        var cleaned = description.lowercased()
        
        // Remove common prefixes/suffixes that don't help with categorization
        let removePhrases = [
            "payment to", "purchase at", "transaction at", "pos purchase",
            "debit card purchase", "credit card purchase", "online purchase",
            "recurring payment", "auto pay", "autopay", "bill pay", "billpay",
            "electronic payment", "ach", "direct debit", "wire transfer",
            "check", "deposit", "withdrawal", "transfer", "fee", "charge"
        ]
        
        for phrase in removePhrases {
            cleaned = cleaned.replacingOccurrences(of: phrase, with: "")
        }
        
        // Remove location indicators that don't help
        cleaned = cleaned.replacingOccurrences(of: #"\s*\d+\s*"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"[#*]+\d+"#, with: "", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
    
    // MARK: - Pattern Analysis
    
    private func analyzeTransactionPatterns(_ transaction: Transaction) -> TransactionCategory? {
        let description = transaction.description.lowercased()
        let amount = transaction.amount
        
        // Time-based patterns
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        let hour = Int(formatter.string(from: transaction.date)) ?? 12
        
        // Early morning (6-9 AM) small amounts = coffee/breakfast
        if (6...9).contains(hour) && amount < 15 {
            return .dining
        }
        
        // Late night (10 PM - 2 AM) = entertainment or food delivery
        if (22...24).contains(hour) || (0...2).contains(hour) {
            if amount < 30 {
                return .dining
            } else {
                return .entertainment
            }
        }
        
        // Weekend patterns
        let weekday = Calendar.current.component(.weekday, from: transaction.date)
        if [1, 7].contains(weekday) { // Sunday or Saturday
            if amount > 50 && amount < 200 {
                return .shopping // Weekend shopping
            }
        }
        
        // Amount-based patterns
        if amount == 9.99 || amount == 19.99 || amount == 29.99 {
            return .entertainment // Common subscription prices
        }
        
        return nil
    }
    
    // MARK: - Improved Smart Defaults
    
    private func improvedSmartDefault(_ transaction: Transaction) -> TransactionCategory {
        let amount = transaction.amount
        let description = transaction.description.lowercased()
        
        // Always keep financial transactions uncategorized
        let financialTerms = ["transfer", "payment", "deposit", "withdrawal", "fee", "interest", "dividend"]
        if financialTerms.contains(where: { description.contains($0) }) {
            return .uncategorized
        }
        
        // Amount-based smart defaults with confidence
        if amount > 1000 {
            return .housing // Large amounts likely rent/mortgage
        } else if amount > 500 {
            return .shopping // Medium-large amounts likely major purchases
        } else if amount > 100 {
            return .shopping // Medium amounts likely shopping
        } else if amount > 50 {
            return .groceries // Grocery-range amounts
        } else if amount > 20 {
            return .dining // Restaurant-range amounts
        } else {
            return .shopping // Small miscellaneous purchases
        }
    }
}