import Foundation

@MainActor
class BudgetManager: ObservableObject {
    @Published var budgets: [Budget] = []
    
    private let userDefaults = UserDefaults.standard
    private let budgetsKey = "SavedBudgets"
    
    init() {
        loadBudgets()
        createSampleBudgetIfNeeded()
    }
    
    // MARK: - Budget Management
    
    func addBudget(_ budget: Budget) {
        budgets.append(budget)
        saveBudgets()
    }
    
    func updateBudget(_ budget: Budget) {
        if let index = budgets.firstIndex(where: { $0.id == budget.id }) {
            budgets[index] = budget
            saveBudgets()
        }
    }
    
    func deleteBudget(_ budget: Budget) {
        budgets.removeAll { $0.id == budget.id }
        saveBudgets()
    }
    
    // Get active budget for a specific category
    func activeBudget(for category: TransactionCategory) -> Budget? {
        return budgets.first { $0.category == category && $0.isActive }
    }
    
    // Get all active budgets
    var activeBudgets: [Budget] {
        return budgets.filter { $0.isActive }
    }
    
    // MARK: - Spending Analysis
    
    func spending(for budget: Budget, in transactions: [Transaction]) -> Double {
        return transactions
            .filter { transaction in
                transaction.category == budget.category &&
                transaction.type == .expense &&
                transaction.date >= budget.startDate &&
                transaction.date <= budget.endDate
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    func spendingPercentage(for budget: Budget, in transactions: [Transaction]) -> Double {
        let spent = spending(for: budget, in: transactions)
        return budget.amount > 0 ? (spent / budget.amount) * 100 : 0
    }
    
    func remainingBudget(for budget: Budget, in transactions: [Transaction]) -> Double {
        let spent = spending(for: budget, in: transactions)
        return max(0, budget.amount - spent)
    }
    
    func isOverBudget(for budget: Budget, in transactions: [Transaction]) -> Bool {
        let spent = spending(for: budget, in: transactions)
        return spent > budget.amount
    }
    
    // MARK: - Test Data Creation
    
    private func createSampleBudgetIfNeeded() {
        // Only create if no dining budget exists
        if activeBudget(for: .dining) == nil {
            let diningBudget = Budget(
                category: .dining,
                amount: 200.0, // $200 monthly dining budget
                period: .monthly,
                startDate: Calendar.current.startOfMonth(for: Date()) ?? Date()
            )
            budgets.append(diningBudget)
            saveBudgets()
        }
    }
    
    // MARK: - Persistence
    
    private func saveBudgets() {
        do {
            let data = try JSONEncoder().encode(budgets)
            userDefaults.set(data, forKey: budgetsKey)
        } catch {
            print("Failed to save budgets: \(error)")
        }
    }
    
    private func loadBudgets() {
        guard let data = userDefaults.data(forKey: budgetsKey) else { return }
        
        do {
            budgets = try JSONDecoder().decode([Budget].self, from: data)
        } catch {
            print("Failed to load budgets: \(error)")
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }
}
