import Foundation

@MainActor
class SmartCategorizationService: ObservableObject {
    @Published var reviewQueue: [TransactionReview] = []
    @Published var learningStats = LearningStats()
    
    private let categoryService = CategoryService()
    private let personalLearningEngine = PersonalLearningEngine()
    
    // MARK: - Smart Categorization Pipeline
    
    func categorizeTransactions(_ transactions: [Transaction]) async -> [Transaction] {
        var processedTransactions: [Transaction] = []
        var needsReview: [TransactionReview] = []
        
        for transaction in transactions {
            let result = await smartCategorize(transaction)
            
            switch result.confidence {
            case 0.95...1.0:
                // High confidence - auto-categorize
                processedTransactions.append(result.transaction)
                learningStats.highConfidenceCount += 1
                
            case 0.70..<0.95:
                // Medium confidence - add suggestions but auto-categorize
                var enhancedTransaction = result.transaction
                processedTransactions.append(enhancedTransaction)
                
                // Add to review queue with suggestions for user to verify later
                let review = TransactionReview(
                    transaction: enhancedTransaction,
                    confidence: result.confidence,
                    alternatives: result.alternatives,
                    reason: result.reason,
                    priority: .medium
                )
                needsReview.append(review)
                learningStats.mediumConfidenceCount += 1
                
            default:
                // Low confidence - requires review
                processedTransactions.append(result.transaction)
                let review = TransactionReview(
                    transaction: result.transaction,
                    confidence: result.confidence,
                    alternatives: result.alternatives,
                    reason: result.reason,
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
        
        return processedTransactions
    }
    
    private func smartCategorize(_ transaction: Transaction) async -> SmartCategorizationResult {
        // Step 1: Check personal learning engine first
        if let personalResult = await personalLearningEngine.predictCategory(for: transaction) {
            return SmartCategorizationResult(
                transaction: Transaction(
                    id: transaction.id,
                    date: transaction.date,
                    description: transaction.description,
                    amount: transaction.amount,
                    category: personalResult.category,
                    type: transaction.type
                ),
                confidence: personalResult.confidence,
                alternatives: personalResult.alternatives,
                reason: "Based on your past categorization patterns"
            )
        }
        
        // Step 2: Enhanced rule-based categorization
        let (ruleCategory, ruleConfidence) = Transaction.predictCategoryWithConfidence(
            from: transaction.description, 
            amount: transaction.amount
        )
        
        // Step 3: Context analysis for ambiguous cases
        let contextualResult = await analyzeContextualClues(transaction, ruleCategory: ruleCategory, ruleConfidence: ruleConfidence)
        
        // Step 4: Generate alternatives for uncertain cases
        let alternatives = generateAlternatives(
            transaction: transaction,
            primaryCategory: contextualResult.category,
            confidence: contextualResult.confidence
        )
        
        let finalTransaction = Transaction(
            id: transaction.id,
            date: transaction.date,
            description: transaction.description,
            amount: transaction.amount,
            category: contextualResult.category,
            type: transaction.type
        )
        
        return SmartCategorizationResult(
            transaction: finalTransaction,
            confidence: contextualResult.confidence,
            alternatives: alternatives,
            reason: contextualResult.reason
        )
    }
    
    // MARK: - Contextual Analysis
    
    private func analyzeContextualClues(_ transaction: Transaction, ruleCategory: TransactionCategory, ruleConfidence: Double) async -> (category: TransactionCategory, confidence: Double, reason: String) {
        
        var adjustedConfidence = ruleConfidence
        var finalCategory = ruleCategory
        var reason = "Rule-based categorization"
        
        let description = transaction.description.lowercased()
        let amount = transaction.amount
        
        // Time-based context
        let timeContext = analyzeTimeContext(transaction.date, amount: amount)
        if timeContext.confidence > 0 {
            adjustedConfidence = max(adjustedConfidence, timeContext.confidence)
            if timeContext.confidence > ruleConfidence {
                finalCategory = timeContext.category
                reason = timeContext.reason
            }
        }
        
        // Amount pattern analysis
        let amountContext = analyzeAmountPatterns(amount: amount, description: description)
        if amountContext.confidence > adjustedConfidence {
            finalCategory = amountContext.category
            adjustedConfidence = amountContext.confidence
            reason = amountContext.reason
        }
        
        // Merchant chain analysis
        let merchantContext = analyzeMerchantChains(description: description, amount: amount)
        if merchantContext.confidence > adjustedConfidence {
            finalCategory = merchantContext.category
            adjustedConfidence = merchantContext.confidence
            reason = merchantContext.reason
        }
        
        // Special ambiguity handling
        let ambiguityResult = handleCommonAmbiguities(description: description, amount: amount, currentCategory: finalCategory)
        if ambiguityResult.needsReview {
            adjustedConfidence = min(adjustedConfidence, 0.6) // Force into review queue
            reason = ambiguityResult.reason
        }
        
        return (finalCategory, adjustedConfidence, reason)
    }
    
    private func analyzeTimeContext(_ date: Date, amount: Double) -> (category: TransactionCategory, confidence: Double, reason: String) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        
        // Early morning coffee/breakfast patterns
        if (6...9).contains(hour) && amount < 15 {
            return (.dining, 0.8, "Early morning small purchase - likely coffee/breakfast")
        }
        
        // Lunch time patterns
        if (11...14).contains(hour) && (5...25).contains(amount) {
            return (.dining, 0.75, "Lunch time purchase in typical lunch price range")
        }
        
        // Evening entertainment/dining
        if (18...23).contains(hour) && amount > 30 {
            return (.entertainment, 0.7, "Evening purchase - likely entertainment or dinner")
        }
        
        // Weekend patterns
        if [1, 7].contains(weekday) && (50...200).contains(amount) {
            return (.shopping, 0.65, "Weekend purchase in shopping range")
        }
        
        return (.uncategorized, 0, "No clear time-based pattern")
    }
    
    private func analyzeAmountPatterns(amount: Double, description: String) -> (category: TransactionCategory, confidence: Double, reason: String) {
        // Subscription amount patterns
        let commonSubscriptions = [9.99, 19.99, 29.99, 49.99, 99.99, 4.99, 14.99]
        if commonSubscriptions.contains(where: { abs(amount - $0) < 0.01 }) {
            return (.entertainment, 0.85, "Common subscription price point")
        }
        
        // Gas station amount patterns (typically $20-80, often ending in .9)
        if (20...80).contains(amount) && description.contains(where: { ["shell", "chevron", "exxon", "bp", "mobil"].contains($0.lowercased()) }) {
            let lastDigits = Int((amount * 100).truncatingRemainder(dividingBy: 100))
            if [9, 19, 29, 39, 49, 59, 69, 79, 89, 99].contains(lastDigits) {
                return (.transportation, 0.9, "Gas station with typical fuel pricing pattern")
            }
        }
        
        // Grocery patterns (common total amounts)
        if [25.67, 34.56, 47.89, 52.34, 67.43].contains(where: { abs(amount - $0) < 20 }) &&
           (20...150).contains(amount) {
            return (.groceries, 0.75, "Amount pattern typical of grocery shopping")
        }
        
        return (.uncategorized, 0, "No clear amount-based pattern")
    }
    
    private func analyzeMerchantChains(description: String, amount: Double) -> (category: TransactionCategory, confidence: Double, reason: String) {
        let desc = description.lowercased()
        
        // Multi-purpose merchants - use amount to disambiguate
        if desc.contains("target") {
            if amount < 30 {
                return (.groceries, 0.8, "Target - small amount likely groceries/essentials")
            } else if amount > 100 {
                return (.shopping, 0.8, "Target - large amount likely general merchandise")
            } else {
                return (.shopping, 0.6, "Target - medium amount, category uncertain")
            }
        }
        
        if desc.contains("walmart") {
            if amount < 50 {
                return (.groceries, 0.8, "Walmart - small amount likely groceries")
            } else {
                return (.shopping, 0.7, "Walmart - larger amount likely general merchandise")
            }
        }
        
        if desc.contains("amazon") {
            if amount < 25 {
                return (.shopping, 0.7, "Amazon - small amount likely household items")
            } else if amount > 100 {
                return (.shopping, 0.8, "Amazon - large amount likely major purchase")
            } else {
                return (.shopping, 0.6, "Amazon - medium amount, uncertain category")
            }
        }
        
        if desc.contains("costco") {
            if amount > 100 {
                return (.groceries, 0.85, "Costco - large amount typical of bulk grocery shopping")
            } else {
                return (.groceries, 0.75, "Costco - likely groceries but smaller than typical")
            }
        }
        
        return (.uncategorized, 0, "No specific merchant chain pattern")
    }
    
    private func handleCommonAmbiguities(description: String, amount: Double, currentCategory: TransactionCategory) -> (needsReview: Bool, reason: String) {
        let desc = description.lowercased()
        
        // Known ambiguous merchants
        let ambiguousMerchants = [
            "amazon", "target", "walmart", "cvs", "walgreens", "shell", "chevron",
            "exxon", "bp", "7-eleven", "wawa", "sheetz"
        ]
        
        for merchant in ambiguousMerchants {
            if desc.contains(merchant) {
                return (true, "Merchant '\(merchant)' sells multiple categories of items - needs verification")
            }
        }
        
        // Vague descriptions
        let vagueTerms = ["purchase", "payment", "transaction", "pos", "debit", "credit"]
        if vagueTerms.contains(where: { desc.contains($0) }) && !desc.contains("specific merchant name") {
            return (true, "Vague transaction description - manual review recommended")
        }
        
        // Unusual amounts for category
        if currentCategory == .dining && amount > 100 {
            return (true, "Large amount for dining category - might be catering or group meal")
        }
        
        if currentCategory == .groceries && amount > 300 {
            return (true, "Very large grocery amount - might include non-grocery items")
        }
        
        return (false, "No ambiguity detected")
    }
    
    private func generateAlternatives(transaction: Transaction, primaryCategory: TransactionCategory, confidence: Double) -> [TransactionCategory] {
        let description = transaction.description.lowercased()
        let amount = transaction.amount
        
        var alternatives: [TransactionCategory] = []
        
        // Generate contextual alternatives based on merchant
        if description.contains("amazon") {
            alternatives = [.shopping, .entertainment, .groceries, .healthcare]
        } else if description.contains("target") || description.contains("walmart") {
            alternatives = [.shopping, .groceries]
        } else if description.contains("cvs") || description.contains("walgreens") {
            alternatives = [.healthcare, .shopping, .dining]
        } else if description.contains("shell") || description.contains("chevron") {
            alternatives = [.transportation, .dining]
        } else {
            // Generate alternatives based on amount and common categories
            if amount < 30 {
                alternatives = [.dining, .shopping, .groceries]
            } else if amount < 100 {
                alternatives = [.shopping, .groceries, .entertainment]
            } else {
                alternatives = [.shopping, .housing, .transportation]
            }
        }
        
        // Remove the primary category from alternatives
        alternatives.removeAll { $0 == primaryCategory }
        
        // Ensure we don't suggest uncategorized as an alternative
        alternatives.removeAll { $0 == .uncategorized }
        
        // Limit to top 3 most likely alternatives
        return Array(alternatives.prefix(3))
    }
    
    // MARK: - User Feedback Learning
    
    func userCorrectedCategory(for transaction: Transaction, to category: TransactionCategory) {
        // Remove from review queue if present
        reviewQueue.removeAll { $0.transaction.id == transaction.id }
        
        // Learn from this correction
        personalLearningEngine.learnFromCorrection(
            description: transaction.description,
            amount: transaction.amount,
            originalCategory: transaction.category,
            correctedCategory: category
        )
        
        // Update learning stats
        learningStats.userCorrections += 1
        learningStats.calculateAccuracy()
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
            estimatedAccuracy: learningStats.estimatedAccuracy
        )
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
    
    func calculateAccuracy() {
        let total = totalProcessed
        if total > 0 {
            // Estimate accuracy based on confidence distribution and user feedback
            let highConfidenceAccuracy = 0.95
            let mediumConfidenceAccuracy = 0.80
            let lowConfidenceAccuracy = 0.50
            
            let weightedAccuracy = (
                Double(highConfidenceCount) * highConfidenceAccuracy +
                Double(mediumConfidenceCount) * mediumConfidenceAccuracy +
                Double(lowConfidenceCount) * lowConfidenceAccuracy
            ) / Double(total)
            
            // Adjust based on user feedback
            let feedbackTotal = userCorrections + userConfirmations
            if feedbackTotal > 0 {
                let userAccuracy = Double(userConfirmations) / Double(feedbackTotal)
                estimatedAccuracy = (weightedAccuracy + userAccuracy) / 2.0
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
    
    var reviewRate: Double {
        let needsReview = mediumConfidence + lowConfidence
        return totalTransactions > 0 ? Double(needsReview) / Double(totalTransactions) : 0
    }
}
