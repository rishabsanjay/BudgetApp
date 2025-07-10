import SwiftUI

struct SmartReviewView: View {
    @ObservedObject var smartService: SmartCategorizationService
    @ObservedObject var transactionManager: TransactionManager
    @State private var currentReviewIndex = 0
    @State private var showingInsights = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if smartService.reviewQueue.isEmpty {
                    EmptyReviewView(smartService: smartService)
                } else {
                    reviewContent
                }
            }
            .navigationTitle("Smart Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Insights") {
                        showingInsights = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingInsights) {
            LearningInsightsView(smartService: smartService)
        }
    }
    
    private var reviewContent: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressView(value: Double(currentReviewIndex), total: Double(smartService.reviewQueue.count))
                .padding()
            
            Text("\(currentReviewIndex + 1) of \(smartService.reviewQueue.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if currentReviewIndex < smartService.reviewQueue.count {
                let review = smartService.reviewQueue[currentReviewIndex]
                
                ScrollView {
                    VStack(spacing: 20) {
                        TransactionReviewCard(review: review)
                        
                        CategorySelectionView(
                            review: review,
                            onCategorySelected: { category in
                                handleCategorySelection(review: review, category: category)
                            },
                            onMarkCorrect: {
                                handleMarkCorrect(review: review)
                            }
                        )
                    }
                    .padding()
                }
            }
        }
    }
    
    private func handleCategorySelection(review: TransactionReview, category: TransactionCategory) {
        // Update the transaction
        transactionManager.categorizeTransaction(review.transaction, as: category)
        
        // Learn from user correction
        smartService.userCorrectedCategory(for: review.transaction, to: category)
        
        // Move to next review
        moveToNextReview()
    }
    
    private func handleMarkCorrect(review: TransactionReview) {
        // Mark as correct in learning system
        smartService.markAsCorrect(transaction: review.transaction)
        
        // Move to next review
        moveToNextReview()
    }
    
    private func moveToNextReview() {
        if currentReviewIndex < smartService.reviewQueue.count - 1 {
            currentReviewIndex += 1
        } else {
            // Review complete
            currentReviewIndex = 0
        }
    }
}

struct TransactionReviewCard: View {
    let review: TransactionReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(review.transaction.description)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(review.transaction.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("$\(review.transaction.amount, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ConfidenceIndicator(confidence: review.confidence)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: review.transaction.category.icon)
                        .foregroundColor(Color(review.transaction.category.color))
                    
                    Text(review.transaction.category.rawValue)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if review.priority == .high {
                        Text("NEEDS REVIEW")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(review.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct CategorySelectionView: View {
    let review: TransactionReview
    let onCategorySelected: (TransactionCategory) -> Void
    let onMarkCorrect: () -> Void
    
    @State private var showingAllCategories = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Is this correct?")
                    .font(.headline)
                
                Spacer()
                
                Button("Looks Good") {
                    onMarkCorrect()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if !review.alternatives.isEmpty {
                Text("Or choose a different category:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(review.alternatives, id: \.self) { category in
                        Button(action: {
                            onCategorySelected(category)
                        }) {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(category.color))
                                
                                Text(category.rawValue)
                                    .font(.subheadline)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Button(action: {
                showingAllCategories = true
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("Choose Different Category")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingAllCategories) {
            AllCategoriesSelectionView(onCategorySelected: onCategorySelected)
        }
    }
}

struct AllCategoriesSelectionView: View {
    let onCategorySelected: (TransactionCategory) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TransactionCategory.allCases, id: \.self) { category in
                    if category != .uncategorized {
                        Button(action: {
                            onCategorySelected(category)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(category.color))
                                    .frame(width: 24)
                                
                                Text(category.rawValue)
                                    .font(.body)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double
    
    private var color: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private var text: String {
        switch confidence {
        case 0.8...1.0: return "High"
        case 0.6..<0.8: return "Medium"
        default: return "Low"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.caption)
                .foregroundColor(color)
        }
    }
}

struct EmptyReviewView: View {
    @ObservedObject var smartService: SmartCategorizationService
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("All Caught Up!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("No transactions need review right now.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            let stats = smartService.getAccuracyStats()
            
            VStack(spacing: 12) {
                Text("Current Accuracy Stats")
                    .font(.headline)
                
                HStack(spacing: 30) {
                    StatItem(
                        title: "High Confidence",
                        value: "\(stats.highConfidence)",
                        color: .green
                    )
                    
                    StatItem(
                        title: "Medium Confidence",
                        value: "\(stats.mediumConfidence)",
                        color: .orange
                    )
                    
                    StatItem(
                        title: "Low Confidence",
                        value: "\(stats.lowConfidence)",
                        color: .red
                    )
                }
                
                Text("Estimated Accuracy: \(Int(stats.estimatedAccuracy * 100))%")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct LearningInsightsView: View {
    @ObservedObject var smartService: SmartCategorizationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let stats = smartService.getAccuracyStats()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accuracy Overview")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Estimated Accuracy")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(Int(stats.estimatedAccuracy * 100))%")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Review Rate")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(Int(stats.reviewRate * 100))%")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Confidence Distribution")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ConfidenceBar(
                                title: "High Confidence",
                                count: stats.highConfidence,
                                total: stats.totalTransactions,
                                color: .green
                            )
                            
                            ConfidenceBar(
                                title: "Medium Confidence",
                                count: stats.mediumConfidence,
                                total: stats.totalTransactions,
                                color: .orange
                            )
                            
                            ConfidenceBar(
                                title: "Low Confidence",
                                count: stats.lowConfidence,
                                total: stats.totalTransactions,
                                color: .red
                            )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Learning Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ConfidenceBar: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(count) (\(Int(percentage * 100))%)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}