import SwiftUI

struct BudgetSetupView: View {
    @ObservedObject var budgetManager: BudgetManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: TransactionCategory = .groceries
    @State private var budgetAmount: String = ""
    @State private var budgetPeriod: BudgetPeriod = .monthly
    @State private var startDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Budget Details") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("$0.00", text: $budgetAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Period", selection: $budgetPeriod) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            HStack {
                                Image(systemName: period.icon)
                                Text(period.rawValue)
                            }
                            .tag(period)
                        }
                    }
                    
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }
                
                if let existingBudget = budgetManager.activeBudget(for: selectedCategory) {
                    Section("Current Budget") {
                        HStack {
                            Text("Existing Budget")
                            Spacer()
                            Text(formatAmount(existingBudget.amount))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Period")
                            Spacer()
                            Text(existingBudget.periodLabel)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBudget()
                    }
                    .disabled(budgetAmount.isEmpty || Double(budgetAmount) == nil)
                }
            }
        }
    }
    
    private func saveBudget() {
        guard let amount = Double(budgetAmount), amount > 0 else { return }
        
        // Remove existing budget for this category if any
        if let existingBudget = budgetManager.activeBudget(for: selectedCategory) {
            budgetManager.deleteBudget(existingBudget)
        }
        
        let budget = Budget(
            category: selectedCategory,
            amount: amount,
            period: budgetPeriod,
            startDate: startDate
        )
        
        budgetManager.addBudget(budget)
        dismiss()
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}