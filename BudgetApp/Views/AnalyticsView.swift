import SwiftUI

struct AnalyticsView: View {
    let transactions: [Transaction]
    @State private var selectedTimeFrame: TimeFrame = .month
    
    enum TimeFrame: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timeFramePicker
                    
                    summaryCards
                    
                    categoryBreakdown
                }
                .padding()
            }
            .navigationTitle("Analytics")
        }
    }
    
    private var timeFramePicker: some View {
        Picker("Time Frame", selection: $selectedTimeFrame) {
            ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                Text(timeFrame.rawValue).tag(timeFrame)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var summaryCards: some View {
        HStack {
            SummaryCard(
                title: "Income",
                amount: totalIncome,
                color: .green,
                icon: "arrow.up.circle.fill"
            )
            
            SummaryCard(
                title: "Expenses",
                amount: totalExpenses,
                color: .red,
                icon: "arrow.down.circle.fill"
            )
        }
    }
    
    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
            
            ForEach(categoryTotals.sorted(by: { $0.value > $1.value }), id: \.key) { category, total in
                CategoryRow(
                    category: category,
                    amount: total,
                    percentage: (total / totalExpenses) * 100
                )
            }
        }
    }
    
    private var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions.filter { transaction in
            switch selectedTimeFrame {
            case .week:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    private var totalIncome: Double {
        filteredTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var totalExpenses: Double {
        filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var categoryTotals: [TransactionCategory: Double] {
        var totals: [TransactionCategory: Double] = [:]
        
        for transaction in filteredTransactions where transaction.type == .expense {
            totals[transaction.category, default: 0] += transaction.amount
        }
        
        return totals
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(formatAmount(amount))
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct CategoryRow: View {
    let category: TransactionCategory
    let amount: Double
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(Color(category.color))
                Text(category.rawValue)
                Spacer()
                Text(formatAmount(amount))
                    .bold()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(category.color))
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}