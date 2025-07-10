import SwiftUI

struct CategoryInsightsView: View {
    @ObservedObject var transactionManager: TransactionManager
    @StateObject private var smartCategorizationService = SmartCategorizationService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    enhancementSection
                    categoriesBreakdownSection
                    accuracySection
                }
                .padding()
            }
            .navigationTitle("Category Insights")
            .navigationBarTitleDisplayMode(.large)
            .task {
                Task {
                    await smartCategorizationService.categorizeAllTransactions(transactionManager.transactions)
                }
            }
        }
    }
    
    private var enhancementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Categorization")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            Button {
                Task {
                    transactionManager.enhanceAllCategorization()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16, weight: .medium))
                    Text("Enhance All Categories")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.purple)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Uses advanced AI to improve transaction categorization based on merchant names, amounts, and patterns.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var categoriesBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories Breakdown")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            let categoryBreakdown = getCategoryBreakdown()
            
            if categoryBreakdown.isEmpty {
                Text("No transactions to categorize")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(categoryBreakdown, id: \.category) { item in
                    CategoryBreakdownRow(
                        category: item.category,
                        count: item.count,
                        percentage: item.percentage,
                        totalAmount: item.totalAmount
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var accuracySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categorization Accuracy")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            let stats = transactionManager.getCategorizationStats()
            
            VStack(spacing: 12) {
                HStack {
                    Text("\(stats.categorized) of \(stats.total) transactions categorized")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(stats.accuracy))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(stats.accuracy > 70 ? .green : stats.accuracy > 40 ? .orange : .red)
                }
                
                ProgressView(value: stats.accuracy, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: stats.accuracy > 70 ? .green : stats.accuracy > 40 ? .orange : .red))
                
                Text("\(String(format: "%.1f", stats.accuracy))% categorized")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func getCategoryBreakdown() -> [CategoryBreakdownItem] {
        let transactions = transactionManager.transactions
        let grouped = Dictionary(grouping: transactions) { $0.category }
        
        return grouped.map { category, categoryTransactions in
            let count = categoryTransactions.count
            let percentage = Double(count) / Double(transactions.count) * 100
            let totalAmount = categoryTransactions.reduce(0) { $0 + $1.amount }
            
            return CategoryBreakdownItem(
                category: category,
                count: count,
                percentage: percentage,
                totalAmount: totalAmount
            )
        }.sorted { $0.count > $1.count }
    }
}

struct CategoryBreakdownItem {
    let category: TransactionCategory
    let count: Int
    let percentage: Double
    let totalAmount: Double
}

struct CategoryBreakdownRow: View {
    let category: TransactionCategory
    let count: Int
    let percentage: Double
    let totalAmount: Double
    
    private var categoryColor: Color {
        switch category {
        case .groceries: return .green
        case .utilities: return .orange
        case .entertainment: return .purple
        case .transportation: return .blue
        case .dining: return .red
        case .shopping: return .pink
        case .healthcare: return .red
        case .housing: return .brown
        case .education: return .cyan
        case .transfers: return .indigo
        case .uncategorized: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(categoryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(count) transactions • $\(totalAmount, specifier: "%.2f")")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(Int(percentage))%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(categoryColor)
        }
        .padding(.vertical, 4)
    }
}