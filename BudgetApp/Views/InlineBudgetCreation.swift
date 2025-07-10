import SwiftUI

struct InlineBudgetCreation: View {
    @ObservedObject var budgetManager: BudgetManager
    let onComplete: () -> Void
    
    @State private var selectedCategory: TransactionCategory = .groceries
    @State private var budgetAmount: String = ""
    @State private var budgetPeriod: BudgetPeriod = .monthly
    @State private var startDate = Date()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Create Budget")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                Text("Set spending limits for your categories")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            // Category selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TransactionCategory.allCases.filter { $0 != .uncategorized }, id: \.self) { category in
                            BudgetCategoryChip(
                                category: category,
                                isSelected: selectedCategory == category,
                                hasExistingBudget: budgetManager.activeBudget(for: category) != nil
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Amount and period
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("$")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("500", text: $budgetAmount)
                            .font(.system(size: 16))
                            .keyboardType(.decimalPad)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Period")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Picker("Period", selection: $budgetPeriod) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            HStack {
                                Image(systemName: period.icon)
                                Text(period.rawValue)
                            }
                            .tag(period)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // Start date
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Date")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                DatePicker("Budget Start Date", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // Existing budget warning
            if let existingBudget = budgetManager.activeBudget(for: selectedCategory) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Existing Budget")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("This will replace your current \(formatAmount(existingBudget.amount)) \(existingBudget.period.rawValue.lowercased()) budget")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onComplete()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Button {
                    saveBudget()
                } label: {
                    Text("Create Budget")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(canSave ? Color.primary : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(!canSave)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
    
    private var canSave: Bool {
        !budgetAmount.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(budgetAmount) != nil &&
        Double(budgetAmount) ?? 0 > 0
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
        onComplete()
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct BudgetCategoryChip: View {
    let category: TransactionCategory
    let isSelected: Bool
    let hasExistingBudget: Bool
    let action: () -> Void
    
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
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : categoryColor)
                    
                    if hasExistingBudget {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isSelected ? .white : categoryColor)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .offset(x: 12, y: -8)
                    }
                }
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : categoryColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? categoryColor : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasExistingBudget && !isSelected ? categoryColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}