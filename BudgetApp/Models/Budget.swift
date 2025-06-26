import Foundation

struct Budget: Identifiable, Codable {
    let id = UUID()
    let category: TransactionCategory
    let amount: Double
    let period: BudgetPeriod
    let startDate: Date
    
    init(category: TransactionCategory, amount: Double, period: BudgetPeriod, startDate: Date = Date()) {
        self.category = category
        self.amount = amount
        self.period = period
        self.startDate = startDate
    }
    
    // Calculate the end date for this budget period
    var endDate: Date {
        let calendar = Calendar.current
        switch period {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        }
    }
    
    // Check if this budget is currently active
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    // Get the current period label (e.g., "January 2024", "Q1 2024")
    var periodLabel: String {
        let formatter = DateFormatter()
        switch period {
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: startDate)
        case .quarterly:
            let quarter = Calendar.current.component(.month, from: startDate) / 3 + 1
            let year = Calendar.current.component(.year, from: startDate)
            return "Q\(quarter) \(year)"
        case .yearly:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: startDate)
        }
    }
}

enum BudgetPeriod: String, CaseIterable, Codable {
    case monthly = "Monthly"
    case quarterly = "Quarterly" 
    case yearly = "Yearly"
    
    var icon: String {
        switch self {
        case .monthly: return "calendar"
        case .quarterly: return "calendar.badge.clock"
        case .yearly: return "calendar.year"
        }
    }
}