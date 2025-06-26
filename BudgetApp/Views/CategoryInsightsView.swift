import SwiftUI

struct CategoryInsightsView: View {
    @ObservedObject var transactionManager: TransactionManager
    @State private var showingEnhancementSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Categorization Stats Card
                CategorizationStatsCard(transactionManager: transactionManager)
                
                // Category Breakdown
                CategoryBreakdownView(transactions: transactionManager.transactions)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        transactionManager.enhanceAllCategorization()
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Enhance All Categorization")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showingEnhancementSheet = true
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("How Categorization Works")
                        }
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Category Insights")
            .sheet(isPresented: $showingEnhancementSheet) {
                CategorizationHelpView()
            }
        }
    }
}

struct CategorizationStatsCard: View {
    @ObservedObject var transactionManager: TransactionManager
    
    var body: some View {
        let stats = transactionManager.getCategorizationStats()
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundColor(.blue)
                Text("Categorization Overview")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(stats.categorized)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Categorized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(stats.total - stats.categorized)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Uncategorized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            ProgressView(value: stats.percentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: stats.percentage > 70 ? .green : stats.percentage > 40 ? .orange : .red))
            
            HStack {
                Text("\(String(format: "%.1f", stats.percentage))% categorized")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(stats.total) total transactions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CategoryBreakdownView: View {
    let transactions: [Transaction]
    
    var categoryStats: [(category: TransactionCategory, count: Int, percentage: Double)] {
        let totalCount = transactions.count
        let categoryCounts = Dictionary(grouping: transactions, by: { $0.category })
            .mapValues { $0.count }
        
        return TransactionCategory.allCases.compactMap { category in
            let count = categoryCounts[category] ?? 0
            let percentage = totalCount > 0 ? Double(count) / Double(totalCount) * 100 : 0
            return count > 0 ? (category: category, count: count, percentage: percentage) : nil
        }
        .sorted { $0.count > $1.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                Text("Category Breakdown")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(categoryStats, id: \.category) { stat in
                    HStack {
                        Image(systemName: stat.category.icon)
                            .foregroundColor(Color(stat.category.color))
                            .frame(width: 20)
                        
                        Text(stat.category.rawValue)
                            .font(.body)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("\(stat.count)")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("\(String(format: "%.1f", stat.percentage))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CategorizationHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How Smart Categorization Works")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Our enhanced categorization system uses multiple strategies to automatically categorize your transactions:")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        CategorizationStepView(
                            step: "1",
                            title: "Exact Merchant Matching",
                            description: "Identifies known merchants like Starbucks, Amazon, McDonald's, etc.",
                            confidence: "95%"
                        )
                        
                        CategorizationStepView(
                            step: "2",
                            title: "Enhanced Keyword Analysis",
                            description: "Analyzes transaction descriptions for category-specific terms",
                            confidence: "80-90%"
                        )
                        
                        CategorizationStepView(
                            step: "3",
                            title: "Fuzzy Merchant Matching",
                            description: "Matches partial or abbreviated merchant names",
                            confidence: "70-85%"
                        )
                        
                        CategorizationStepView(
                            step: "4",
                            title: "Pattern Recognition",
                            description: "Uses amount patterns, timing, and transaction codes",
                            confidence: "60-75%"
                        )
                        
                        CategorizationStepView(
                            step: "5",
                            title: "Smart Defaults",
                            description: "Intelligent categorization based on amount ranges",
                            confidence: "30-60%"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Categories We Recognize")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(TransactionCategory.allCases.filter { $0 != .uncategorized }, id: \.self) { category in
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(Color(category.color))
                                    Text(category.rawValue)
                                        .font(.caption)
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tips for Better Categorization")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipView(text: "Transactions with clear merchant names work best")
                            TipView(text: "Regular re-categorization improves accuracy over time")
                            TipView(text: "You can always manually correct categories")
                            TipView(text: "Bank transfers and fees are kept uncategorized")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Categorization Help")
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

struct CategorizationStepView: View {
    let step: String
    let title: String
    let description: String
    let confidence: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(step)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                    Text(confidence)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TipView: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .foregroundColor(.yellow)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CategoryInsightsView(transactionManager: TransactionManager())
}