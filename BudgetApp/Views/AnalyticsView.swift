import SwiftUI

struct AnalyticsView: View {
    let transactions: [Transaction]
    @State private var selectedTimeframe: TimeFrame = .month
    @State private var selectedChartType: ChartType = .category
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
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
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Analytics")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Insights into your spending")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedTimeframe == timeframe {
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    Color(.systemGray6)
                                }
                            }
                        )
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
                SummaryCard(
                    title: "Total Spent",
                    value: formatCurrency(totalSpent),
                    icon: "minus.circle.fill",
                    color: .red,
                    trend: .down
                )
                
                SummaryCard(
                    title: "Total Income",
                    value: formatCurrency(totalIncome),
                    icon: "plus.circle.fill",
                    color: .green,
                    trend: .up
                )
            }
            
            SummaryCard(
                title: "Net Change",
                value: formatCurrency(totalIncome - totalSpent),
                icon: netChange >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                color: netChange >= 0 ? .green : .red,
                trend: netChange >= 0 ? .up : .down,
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
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

enum ChartType: String, CaseIterable {
    case category = "Categories"
    case timeline = "Timeline"
    
    var icon: String {
        switch self {
        case .category: return "chart.pie.fill"
        case .timeline: return "chart.line.uptrend.xyaxis"
        }
    }
}

enum Trend {
    case up, down, neutral
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Trend
    let isWide: Bool
    
    init(title: String, value: String, icon: String, color: Color, trend: Trend, isWide: Bool = false) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.trend = trend
        self.isWide = isWide
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: trendIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(trendColor)
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var trendIcon: String {
        switch trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .neutral: return "minus"
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .up: return .green
        case .down: return .red
        case .neutral: return .gray
        }
    }
}

struct CategorySpendingRow: View {
    let category: TransactionCategory
    let amount: Double
    let percentage: Double
    
    private var categoryColor: Color {
        switch category {
        case .groceries: return .green
        case .utilities: return .yellow
        case .entertainment: return .purple
        case .transportation: return .blue
        case .dining: return .orange
        case .shopping: return .pink
        case .healthcare: return .red
        case .housing: return .brown
        case .education: return .cyan
        case .uncategorized: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("\(Int(percentage))% of spending")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(amount))
                .font(.system(size: 16, weight: .bold, design: .rounded))
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
        case .utilities: return .yellow
        case .entertainment: return .purple
        case .transportation: return .blue
        case .dining: return .orange
        case .shopping: return .pink
        case .healthcare: return .red
        case .housing: return .brown
        case .education: return .cyan
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
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // Visual progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [categoryColor.opacity(0.8), categoryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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
