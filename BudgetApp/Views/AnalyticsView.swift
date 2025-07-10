import SwiftUI

struct AnalyticsView: View {
    let transactions: [Transaction]
    @State private var selectedTimeframe: TimeFrame = .month
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Simple header
                    headerSection
                    
                    // Time frame selector
                    timeframeSelector
                    
                    // Summary cards
                    summaryCardsSection
                    
                    // Top spending categories
                    topCategoriesSection
                    
                    // Simple spending breakdown
                    spendingBreakdownSection
                    
                    Spacer(minLength: 100) // Space for tab bar
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Analytics")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Insights into your spending")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chart.bar")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.top, 20)
    }
    
    private var timeframeSelector: some View {
        HStack(spacing: 12) {
            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeframe = timeframe
                    }
                } label: {
                    Text(timeframe.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedTimeframe == timeframe ? Color.primary : Color(.systemGray6))
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
    }
    
    private var summaryCardsSection: some View {
        LazyVStack(spacing: 12) {
            HStack(spacing: 12) {
                SimpleSummaryCard(
                    title: "Total Spent",
                    value: formatCurrency(totalSpent),
                    icon: "minus.circle",
                    color: .red
                )
                
                SimpleSummaryCard(
                    title: "Total Income",
                    value: formatCurrency(totalIncome),
                    icon: "plus.circle",
                    color: .green
                )
            }
            
            SimpleSummaryCard(
                title: "Net Change",
                value: formatCurrency(totalIncome - totalSpent),
                icon: netChange >= 0 ? "arrow.up.circle" : "arrow.down.circle",
                color: netChange >= 0 ? .green : .red,
                isWide: true
            )
        }
    }
    
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Spending Categories")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 12) {
                ForEach(topSpendingCategories.prefix(5), id: \.category) { item in
                    CategorySpendingRow(
                        category: item.category,
                        amount: item.amount,
                        percentage: totalSpent > 0 ? item.amount / totalSpent * 100 : 0
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var spendingBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Breakdown")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            if filteredTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No transactions in this period")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(categoryBreakdown, id: \.category) { item in
                        SpendingBreakdownRow(
                            category: item.category,
                            amount: item.amount,
                            percentage: totalSpent > 0 ? item.amount / totalSpent * 100 : 0
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions.filter { transaction in
            switch selectedTimeframe {
            case .week:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    private var totalSpent: Double {
        filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var totalIncome: Double {
        filteredTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var netChange: Double {
        totalIncome - totalSpent
    }
    
    private var topSpendingCategories: [(category: TransactionCategory, amount: Double)] {
        let categoryTotals = Dictionary(grouping: filteredTransactions.filter { $0.type == .expense }) { $0.category }
            .mapValues { transactions in
                transactions.reduce(0) { $0 + $1.amount }
            }
        
        return categoryTotals.sorted { $0.value > $1.value }
            .map { (category: $0.key, amount: $0.value) }
    }
    
    private var categoryBreakdown: [(category: TransactionCategory, amount: Double)] {
        topSpendingCategories
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Supporting Types and Views

enum TimeFrame: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

// Simplified summary card
struct SimpleSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isWide: Bool
    
    init(title: String, value: String, icon: String, color: Color, isWide: Bool = false) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.isWide = isWide
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: isWide ? 24 : 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CategorySpendingRow: View {
    let category: TransactionCategory
    let amount: Double
    let percentage: Double
    
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
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(categoryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(Int(percentage))% of spending")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(amount))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

struct SpendingBreakdownRow: View {
    let category: TransactionCategory
    let amount: Double
    let percentage: Double
    
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
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(categoryColor)
                        .frame(width: 20)
                    
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(formatCurrency(amount))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            // Simple progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(categoryColor)
                        .frame(
                            width: geometry.size.width * CGFloat(percentage / 100),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.5), value: percentage)
                }
            }
            .frame(height: 6)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
