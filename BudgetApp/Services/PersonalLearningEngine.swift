import Foundation

@MainActor
class PersonalLearningEngine: ObservableObject {
    @Published private var personalMerchantMappings: [String: PersonalMerchantMapping] = [:]
    @Published private var categoryPatterns: [String: CategoryPattern] = [:]
    @Published private var userPreferences = UserPreferences()
    
    // MARK: - Personal Learning
    
    func predictCategory(for transaction: Transaction) async -> PersonalPredictionResult? {
        let description = transaction.description.lowercased()
        let amount = transaction.amount
        
        // Check for exact merchant match in personal mappings
        if let mapping = findPersonalMerchantMapping(description: description) {
            let confidence = calculatePersonalConfidence(mapping: mapping, amount: amount)
            if confidence > 0.7 {
                return PersonalPredictionResult(
                    category: mapping.preferredCategory,
                    confidence: confidence,
                    alternatives: mapping.alternativeCategories,
                    reason: "Based on your \(mapping.usageCount) previous categorizations of '\(mapping.merchantName)'"
                )
            }
        }
        
        // Check for pattern-based predictions
        if let pattern = findMatchingPattern(description: description, amount: amount) {
            return PersonalPredictionResult(
                category: pattern.category,
                confidence: pattern.confidence,
                alternatives: pattern.alternatives,
                reason: "Based on your categorization patterns for similar transactions"
            )
        }
        
        return nil
    }
    
    private func findPersonalMerchantMapping(description: String) -> PersonalMerchantMapping? {
        // Try exact matches first
        for (key, mapping) in personalMerchantMappings {
            if description.contains(key.lowercased()) {
                return mapping
            }
        }
        
        // Try fuzzy matching for similar merchant names
        for (key, mapping) in personalMerchantMappings {
            if areMerchantNamesSimilar(description, key) {
                return mapping
            }
        }
        
        return nil
    }
    
    private func areMerchantNamesSimilar(_ description: String, _ merchantKey: String) -> Bool {
        let desc = description.lowercased()
        let key = merchantKey.lowercased()
        
        // Check if they share significant portions
        let descWords = desc.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        let keyWords = key.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        
        // If any significant word matches, consider them similar
        for descWord in descWords where descWord.count > 3 {
            for keyWord in keyWords where keyWord.count > 3 {
                if descWord.contains(keyWord) || keyWord.contains(descWord) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func findMatchingPattern(description: String, amount: Double) -> CategoryPattern? {
        for (patternKey, pattern) in categoryPatterns {
            if pattern.matches(description: description, amount: amount) {
                return pattern
            }
        }
        return nil
    }
    
    private func calculatePersonalConfidence(mapping: PersonalMerchantMapping, amount: Double) -> Double {
        var confidence = min(0.95, 0.6 + (Double(mapping.usageCount) * 0.05))
        
        // Boost confidence if amount is in typical range for this merchant
        if mapping.typicalAmountRange.contains(amount) {
            confidence += 0.1
        }
        
        // Reduce confidence if user has been inconsistent with this merchant
        if mapping.categoryChanges > 2 {
            confidence -= 0.2
        }
        
        return max(0.0, min(1.0, confidence))
    }
    
    // MARK: - Learning from User Feedback
    
    func learnFromCorrection(description: String, amount: Double, originalCategory: TransactionCategory, correctedCategory: TransactionCategory) {
        let merchantKey = extractMerchantKey(from: description)
        
        if var existingMapping = personalMerchantMappings[merchantKey] {
            // Update existing mapping
            existingMapping.usageCount += 1
            existingMapping.preferredCategory = correctedCategory
            existingMapping.categoryChanges += (originalCategory != correctedCategory) ? 1 : 0
            existingMapping.updateAmountRange(amount)
            existingMapping.lastUpdated = Date()
            
            // Update alternatives based on user behavior
            if !existingMapping.alternativeCategories.contains(originalCategory) && originalCategory != .uncategorized {
                existingMapping.alternativeCategories.append(originalCategory)
            }
            
            personalMerchantMappings[merchantKey] = existingMapping
        } else {
            // Create new mapping
            let newMapping = PersonalMerchantMapping(
                merchantName: merchantKey,
                preferredCategory: correctedCategory,
                usageCount: 1,
                categoryChanges: (originalCategory != correctedCategory) ? 1 : 0,
                typicalAmountRange: amount...amount,
                alternativeCategories: originalCategory != .uncategorized ? [originalCategory] : [],
                lastUpdated: Date()
            )
            personalMerchantMappings[merchantKey] = newMapping
        }
        
        // Learn patterns from this correction
        learnPatternFromCorrection(description: description, amount: amount, category: correctedCategory)
        
        // Update user preferences
        updateUserPreferences(from: correctedCategory, amount: amount)
    }
    
    func reinforceCorrectCategorization(description: String, amount: Double, category: TransactionCategory) {
        let merchantKey = extractMerchantKey(from: description)
        
        if var existingMapping = personalMerchantMappings[merchantKey] {
            existingMapping.usageCount += 1
            existingMapping.updateAmountRange(amount)
            existingMapping.lastUpdated = Date()
            personalMerchantMappings[merchantKey] = existingMapping
        } else {
            let newMapping = PersonalMerchantMapping(
                merchantName: merchantKey,
                preferredCategory: category,
                usageCount: 1,
                categoryChanges: 0,
                typicalAmountRange: amount...amount,
                alternativeCategories: [],
                lastUpdated: Date()
            )
            personalMerchantMappings[merchantKey] = newMapping
        }
        
        reinforcePattern(description: description, amount: amount, category: category)
    }
    
    private func learnPatternFromCorrection(description: String, amount: Double, category: TransactionCategory) {
        // Extract patterns from the description
        let patterns = extractPatterns(from: description)
        
        for pattern in patterns {
            let patternKey = "\(pattern)_\(category.rawValue)"
            
            if var existingPattern = categoryPatterns[patternKey] {
                existingPattern.strength += 1
                existingPattern.confidence = min(0.9, existingPattern.confidence + 0.05)
                existingPattern.updateAmountRange(amount)
                categoryPatterns[patternKey] = existingPattern
            } else {
                let newPattern = CategoryPattern(
                    pattern: pattern,
                    category: category,
                    strength: 1,
                    confidence: 0.6,
                    amountRange: amount...amount,
                    alternatives: []
                )
                categoryPatterns[patternKey] = newPattern
            }
        }
    }
    
    private func reinforcePattern(description: String, amount: Double, category: TransactionCategory) {
        let patterns = extractPatterns(from: description)
        
        for pattern in patterns {
            let patternKey = "\(pattern)_\(category.rawValue)"
            
            if var existingPattern = categoryPatterns[patternKey] {
                existingPattern.strength += 1
                existingPattern.confidence = min(0.95, existingPattern.confidence + 0.02)
                existingPattern.updateAmountRange(amount)
                categoryPatterns[patternKey] = existingPattern
            }
        }
    }
    
    private func extractMerchantKey(from description: String) -> String {
        let cleaned = description.lowercased()
            .replacingOccurrences(of: #"[0-9#*]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        
        // Take the first significant part of the description
        let words = cleaned.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { $0.count > 2 }
        return words.prefix(2).joined(separator: " ")
    }
    
    private func extractPatterns(from description: String) -> [String] {
        var patterns: [String] = []
        let desc = description.lowercased()
        
        // Extract word patterns
        let words = desc.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { $0.count > 3 }
        patterns.append(contentsOf: words)
        
        // Extract prefixes (e.g., "TST*", "SQ *")
        if let prefixMatch = desc.range(of: #"^[a-z]{2,4}\*"#, options: .regularExpression) {
            patterns.append(String(desc[prefixMatch]))
        }
        
        return patterns
    }
    
    private func updateUserPreferences(from category: TransactionCategory, amount: Double) {
        userPreferences.categoryUsage[category, default: 0] += 1
        
        // Update spending patterns
        if let existingRange = userPreferences.categoryAmountRanges[category] {
            let newRange = min(existingRange.lowerBound, amount)...max(existingRange.upperBound, amount)
            userPreferences.categoryAmountRanges[category] = newRange
        } else {
            userPreferences.categoryAmountRanges[category] = amount...amount
        }
    }
    
    // MARK: - Data Management
    
    func exportLearningData() -> PersonalLearningData {
        return PersonalLearningData(
            merchantMappings: personalMerchantMappings,
            categoryPatterns: categoryPatterns,
            userPreferences: userPreferences
        )
    }
    
    func importLearningData(_ data: PersonalLearningData) {
        self.personalMerchantMappings = data.merchantMappings
        self.categoryPatterns = data.categoryPatterns
        self.userPreferences = data.userPreferences
    }
    
    func clearLearningData() {
        personalMerchantMappings.removeAll()
        categoryPatterns.removeAll()
        userPreferences = UserPreferences()
    }
    
    func getInsights() -> LearningInsights {
        return LearningInsights(
            totalMerchantsLearned: personalMerchantMappings.count,
            totalPatternsLearned: categoryPatterns.count,
            mostFrequentCategories: userPreferences.getMostUsedCategories(),
            learningAccuracy: calculateLearningAccuracy()
        )
    }
    
    private func calculateLearningAccuracy() -> Double {
        let totalMappings = personalMerchantMappings.values.reduce(0) { $0 + $1.usageCount }
        let totalChanges = personalMerchantMappings.values.reduce(0) { $0 + $1.categoryChanges }
        
        return totalMappings > 0 ? 1.0 - (Double(totalChanges) / Double(totalMappings)) : 0.0
    }
}

// MARK: - Supporting Models

struct PersonalMerchantMapping {
    let merchantName: String
    var preferredCategory: TransactionCategory
    var usageCount: Int
    var categoryChanges: Int
    var typicalAmountRange: ClosedRange<Double>
    var alternativeCategories: [TransactionCategory]
    var lastUpdated: Date
    
    mutating func updateAmountRange(_ amount: Double) {
        let newLower = min(typicalAmountRange.lowerBound, amount)
        let newUpper = max(typicalAmountRange.upperBound, amount)
        typicalAmountRange = newLower...newUpper
    }
}

struct CategoryPattern {
    let pattern: String
    var category: TransactionCategory
    var strength: Int
    var confidence: Double
    var amountRange: ClosedRange<Double>
    var alternatives: [TransactionCategory]
    
    mutating func updateAmountRange(_ amount: Double) {
        let newLower = min(amountRange.lowerBound, amount)
        let newUpper = max(amountRange.upperBound, amount)
        amountRange = newLower...newUpper
    }
    
    func matches(description: String, amount: Double) -> Bool {
        let desc = description.lowercased()
        let patternMatches = desc.contains(pattern.lowercased())
        let amountMatches = amountRange.contains(amount) || 
                           abs(amount - amountRange.lowerBound) < 10 || 
                           abs(amount - amountRange.upperBound) < 10
        
        return patternMatches && (amountMatches || strength > 5)
    }
}

struct UserPreferences {
    var categoryUsage: [TransactionCategory: Int] = [:]
    var categoryAmountRanges: [TransactionCategory: ClosedRange<Double>] = [:]
    
    func getMostUsedCategories() -> [TransactionCategory] {
        return categoryUsage.sorted { $0.value > $1.value }.map { $0.key }
    }
}

struct PersonalPredictionResult {
    let category: TransactionCategory
    let confidence: Double
    let alternatives: [TransactionCategory]
    let reason: String
}

struct PersonalLearningData: Codable {
    let merchantMappings: [String: PersonalMerchantMapping]
    let categoryPatterns: [String: CategoryPattern]
    let userPreferences: UserPreferences
}

struct LearningInsights {
    let totalMerchantsLearned: Int
    let totalPatternsLearned: Int
    let mostFrequentCategories: [TransactionCategory]
    let learningAccuracy: Double
}

// MARK: - Codable Extensions

extension PersonalMerchantMapping: Codable {}
extension CategoryPattern: Codable {}
extension UserPreferences: Codable {}
