import Foundation

@MainActor
class SmartCategorizationService: ObservableObject {
    static let shared = SmartCategorizationService()
    
    @Published var reviewQueue: [TransactionReview] = []
    @Published var learningStats = LearningStats()
    @Published var isProcessing = false
    @Published var apiErrorMessage: String?
    
    private let categoryService = CategoryService()
    private let personalLearningEngine = PersonalLearningEngine()
    
    // Fina Money API Configuration
    private let finaAPIBaseURL = FinaAPIConfig.baseURL
    private let finaAPIKey = FinaAPIConfig.apiKey
    
    private init() {}
    
    // MARK: - Smart Categorization Pipeline (API-First Approach)
    
    func categorizeAllTransactions(_ transactions: [Transaction]) async {
        // Process transactions for categorization
        let categorizedTransactions = await categorizeTransactions(transactions)
        // This is called from CategoryInsightsView but we don't need to return anything
        // The real categorization happens in TransactionManager
    }
    
    func categorizeTransactions(_ transactions: [Transaction]) async -> [Transaction] {
        isProcessing = true
        defer { isProcessing = false }
        
        var processedTransactions: [Transaction] = []
        var needsReview: [TransactionReview] = []
        
        print("🔄 Starting categorization for \(transactions.count) transactions")
        
        // Step 1: Try Fina Money API for all transactions
        let apiResults = await categorizeWithFinaAPI(transactions)
        
        for (index, transaction) in transactions.enumerated() {
            var categorizedTransaction = transaction
            var confidence: Double = 0.0
            var reason = ""
            var alternatives: [TransactionCategory] = []
            
            // Check if we got a valid API result
            if index < apiResults.count, let apiCategory = apiResults[index] {
                categorizedTransaction.category = apiCategory
                confidence = 0.95 // High confidence for API results
                reason = "Categorized by Fina Money API"
                alternatives = generateAlternatives(for: apiCategory)
                learningStats.apiSuccessCount += 1
                
                print("✅ API categorized: \(transaction.description) -> \(apiCategory)")
                
            } else {
                // Step 2: Fallback to minimal rule-based categorization
                let fallbackResult = await fallbackCategorization(transaction)
                categorizedTransaction.category = fallbackResult.category
                confidence = fallbackResult.confidence
                reason = fallbackResult.reason
                alternatives = fallbackResult.alternatives
                learningStats.fallbackCount += 1
                
                print("⚠️ Fallback categorized: \(transaction.description) -> \(fallbackResult.category)")
            }
            
            // Determine if needs review based on confidence
            switch confidence {
            case 0.90...1.0:
                // High confidence - auto-categorize
                processedTransactions.append(categorizedTransaction)
                learningStats.highConfidenceCount += 1
                
            case 0.70..<0.90:
                // Medium confidence - auto-categorize but flag for review
                processedTransactions.append(categorizedTransaction)
                let review = TransactionReview(
                    transaction: categorizedTransaction,
                    confidence: confidence,
                    alternatives: alternatives,
                    reason: reason,
                    priority: .medium
                )
                needsReview.append(review)
                learningStats.mediumConfidenceCount += 1
                
            default:
                // Low confidence - requires review
                processedTransactions.append(categorizedTransaction)
                let review = TransactionReview(
                    transaction: categorizedTransaction,
                    confidence: confidence,
                    alternatives: alternatives,
                    reason: reason,
                    priority: .high
                )
                needsReview.append(review)
                learningStats.lowConfidenceCount += 1
            }
        }
        
        // Update review queue
        self.reviewQueue.append(contentsOf: needsReview)
        
        // Sort review queue by priority and confidence
        self.reviewQueue.sort { review1, review2 in
            if review1.priority != review2.priority {
                return review1.priority == .high
            }
            return review1.confidence < review2.confidence
        }
        
        // Update learning stats
        learningStats.totalProcessed += transactions.count
        learningStats.calculateAccuracy()
        
        let apiSuccessRate = Double(learningStats.apiSuccessCount) / Double(learningStats.totalProcessed) * 100
        print("📊 Categorization complete. API success rate: \(String(format: "%.1f", apiSuccessRate))%")
        
        return processedTransactions
    }
    
    // MARK: - Fina Money API Integration
    
    private func categorizeWithFinaAPI(_ transactions: [Transaction]) async -> [TransactionCategory?] {
        // Prepare transaction descriptions for API
        let descriptions = transactions.map { $0.description }
        
        // Split into batches of 100 (API limit)
        let batchSize = 100
        var allResults: [TransactionCategory?] = []
        
        for batchStart in stride(from: 0, to: descriptions.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, descriptions.count)
            let batch = Array(descriptions[batchStart..<batchEnd])
            
            print("🌐 Sending batch to Fina API: \(batch.count) transactions")
            
            let batchResults = await sendBatchToFinaAPI(batch)
            allResults.append(contentsOf: batchResults)
        }
        
        return allResults
    }
    
    private func sendBatchToFinaAPI(_ descriptions: [String]) async -> [TransactionCategory?] {
        guard let url = URL(string: finaAPIBaseURL) else {
            print("❌ Invalid Fina API URL")
            return Array(repeating: nil, count: descriptions.count)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(finaAPIKey, forHTTPHeaderField: "x-api-key")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: descriptions)
            request.httpBody = jsonData
            
            print("🔄 Making API request to Fina Money...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API Response Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let categoryStrings = try JSONSerialization.jsonObject(with: data) as? [String] ?? []
                    let categories = categoryStrings.map { mapFinaCategoryToLocal($0) }
                    
                    print("✅ API returned \(categories.count) categories")
                    for (desc, cat) in zip(descriptions, categories) {
                        print("   \(desc) -> \(cat?.rawValue ?? "nil")")
                    }
                    
                    return categories
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ API Error \(httpResponse.statusCode): \(errorString)")
                    await MainActor.run {
                        self.apiErrorMessage = "Fina API Error: \(httpResponse.statusCode)"
                    }
                }
            }
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            await MainActor.run {
                self.apiErrorMessage = "Network error: \(error.localizedDescription)"
            }
        }
        
        // Return nil for all transactions if API fails
        return Array(repeating: nil, count: descriptions.count)
    }
    
    // MARK: - Category Mapping
    
    private func mapFinaCategoryToLocal(_ finaCategory: String) -> TransactionCategory? {
        let normalizedCategory = finaCategory.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Map Fina categories to our local categories
        switch normalizedCategory {
        case "food", "dining", "restaurants", "food & dining":
            return .dining
        case "grocery", "groceries", "supermarket":
            return .groceries
        case "transport", "transportation", "gas", "fuel", "car", "auto", "uber", "taxi":
            return .transportation
        case "entertainment", "movies", "games", "streaming", "subscription":
            return .entertainment
        case "shopping", "retail", "clothes", "clothing", "amazon", "online":
            return .shopping
        case "health", "healthcare", "medical", "pharmacy", "doctor":
            return .healthcare
        case "housing", "rent", "mortgage", "utilities", "home":
            return .housing
        case "education", "school", "books", "learning":
            return .education
        case "income", "salary", "wages", "payroll", "deposit":
            return .transfers  // Map income to transfers since we don't have income category
        case "transfer", "transfers", "bank transfer":
            return .transfers
        case "investment", "investments", "stocks", "crypto", "financial":
            return .transfers  // Map investments to transfers since we don't have investments category
        case "bills", "utilities", "electric", "water", "gas", "internet", "phone":
            return .housing
        default:
            print("⚠️ Unknown Fina category: '\(finaCategory)' - mapping to uncategorized")
            return .uncategorized
        }
    }
    
    // MARK: - Minimal Fallback System
    
    private func fallbackCategorization(_ transaction: Transaction) async -> (category: TransactionCategory, confidence: Double, reason: String, alternatives: [TransactionCategory]) {
        
        // Try personal learning engine first
        if let personalResult = await personalLearningEngine.predictCategory(for: transaction) {
            return (
                category: personalResult.category,
                confidence: personalResult.confidence,
                reason: "Personal learning engine (API unavailable)",
                alternatives: personalResult.alternatives
            )
        }
        
        // Basic rule-based fallback
        let (category, confidence) = Transaction.predictCategoryWithConfidence(
            from: transaction.description,
            amount: transaction.amount
        )
        
        let alternatives = generateBasicAlternatives(for: category, amount: transaction.amount)
        
        return (
            category: category,
            confidence: max(confidence - 0.2, 0.3), // Lower confidence for fallback
            reason: "Rule-based fallback (API unavailable)",
            alternatives: alternatives
        )
    }
    
    private func generateAlternatives(for category: TransactionCategory) -> [TransactionCategory] {
        switch category {
        case .dining:
            return [.groceries, .entertainment, .shopping]
        case .groceries:
            return [.dining, .shopping, .healthcare]
        case .transportation:
            return [.shopping, .entertainment, .dining]
        case .entertainment:
            return [.dining, .shopping, .transportation]
        case .shopping:
            return [.entertainment, .groceries, .healthcare]
        case .healthcare:
            return [.shopping, .groceries, .entertainment]
        case .housing:
            return [.shopping, .healthcare, .transportation]
        case .education:
            return [.shopping, .entertainment, .healthcare]
        default:
            return [.shopping, .dining, .entertainment]
        }
    }
    
    private func generateBasicAlternatives(for category: TransactionCategory, amount: Double) -> [TransactionCategory] {
        if amount < 30 {
            return [.dining, .shopping, .groceries]
        } else if amount < 100 {
            return [.shopping, .groceries, .entertainment]
        } else {
            return [.shopping, .housing, .transportation]
        }
    }
    
    // MARK: - User Feedback Learning
    
    func userCorrectedCategory(for transaction: Transaction, to category: TransactionCategory) {
        // Remove from review queue if present
        reviewQueue.removeAll { $0.transaction.id == transaction.id }
        
        // Learn from this correction for fallback scenarios
        personalLearningEngine.learnFromCorrection(
            description: transaction.description,
            amount: transaction.amount,
            originalCategory: transaction.category,
            correctedCategory: category
        )
        
        // Update learning stats
        learningStats.userCorrections += 1
        learningStats.calculateAccuracy()
        
        print("📚 User correction learned: \(transaction.description) -> \(category)")
    }
    
    func markAsCorrect(transaction: Transaction) {
        // Remove from review queue
        reviewQueue.removeAll { $0.transaction.id == transaction.id }
        
        // Reinforce this categorization
        personalLearningEngine.reinforceCorrectCategorization(
            description: transaction.description,
            amount: transaction.amount,
            category: transaction.category
        )
        
        learningStats.userConfirmations += 1
        learningStats.calculateAccuracy()
    }
    
    // MARK: - Bulk Operations
    
    func processReviewQueue() -> [Transaction] {
        let processedTransactions = reviewQueue.map { $0.transaction }
        reviewQueue.removeAll()
        return processedTransactions
    }
    
    func getAccuracyStats() -> AccuracyStats {
        return AccuracyStats(
            totalTransactions: learningStats.totalProcessed,
            highConfidence: learningStats.highConfidenceCount,
            mediumConfidence: learningStats.mediumConfidenceCount,
            lowConfidence: learningStats.lowConfidenceCount,
            userCorrections: learningStats.userCorrections,
            estimatedAccuracy: learningStats.estimatedAccuracy,
            apiSuccessRate: learningStats.totalProcessed > 0 ? Double(learningStats.apiSuccessCount) / Double(learningStats.totalProcessed) : 0
        )
    }
    
    // MARK: - API Health Check
    
    func testFinaAPIConnection() async -> Bool {
        let testDescriptions = ["Starbucks Coffee", "Shell Gas Station"]
        let results = await sendBatchToFinaAPI(testDescriptions)
        return results.contains { $0 != nil }
    }
}

// MARK: - Supporting Models

struct SmartCategorizationResult {
    let transaction: Transaction
    let confidence: Double
    let alternatives: [TransactionCategory]
    let reason: String
}

struct TransactionReview: Identifiable {
    let id = UUID()
    let transaction: Transaction
    let confidence: Double
    let alternatives: [TransactionCategory]
    let reason: String
    let priority: ReviewPriority
    
    enum ReviewPriority {
        case high, medium, low
    }
}

@MainActor
class LearningStats: ObservableObject {
    @Published var totalProcessed = 0
    @Published var highConfidenceCount = 0
    @Published var mediumConfidenceCount = 0
    @Published var lowConfidenceCount = 0
    @Published var userCorrections = 0
    @Published var userConfirmations = 0
    @Published var estimatedAccuracy: Double = 0.0
    @Published var apiSuccessCount = 0
    @Published var fallbackCount = 0
    
    func calculateAccuracy() {
        let total = totalProcessed
        if total > 0 {
            // Higher base accuracy since we're using professional API
            let highConfidenceAccuracy = 0.98  // API results are very accurate
            let mediumConfidenceAccuracy = 0.85
            let lowConfidenceAccuracy = 0.60
            
            let weightedAccuracy = (
                Double(highConfidenceCount) * highConfidenceAccuracy +
                Double(mediumConfidenceCount) * mediumConfidenceAccuracy +
                Double(lowConfidenceCount) * lowConfidenceAccuracy
            ) / Double(total)
            
            // Adjust based on user feedback
            let feedbackTotal = userCorrections + userConfirmations
            if feedbackTotal > 0 {
                let userAccuracy = Double(userConfirmations) / Double(feedbackTotal)
                estimatedAccuracy = (weightedAccuracy * 0.7) + (userAccuracy * 0.3)
            } else {
                estimatedAccuracy = weightedAccuracy
            }
        }
    }
}

struct AccuracyStats {
    let totalTransactions: Int
    let highConfidence: Int
    let mediumConfidence: Int
    let lowConfidence: Int
    let userCorrections: Int
    let estimatedAccuracy: Double
    let apiSuccessRate: Double
    
    var reviewRate: Double {
        let needsReview = mediumConfidence + lowConfidence
        return totalTransactions > 0 ? Double(needsReview) / Double(totalTransactions) : 0
    }
}