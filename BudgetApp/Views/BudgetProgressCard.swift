import SwiftUI

struct BudgetProgressCard: View {
    let budget: Budget
    let transactions: [Transaction]
    let budgetManager: BudgetManager
    
    private var spent: Double {
        budgetManager.spending(for: budget, in: transactions)
    }
    
    private var remaining: Double {
        budgetManager.remainingBudget(for: budget, in: transactions)
    }
    
    private var percentage: Double {
        budgetManager.spendingPercentage(for: budget, in: transactions)
    }
    
    private var isOverBudget: Bool {
        budgetManager.isOverBudget(for: budget, in: transactions)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack {
                    Image(systemName: budget.category.icon)
                        .foregroundColor(Color(budget.category.color))
                    Text(budget.category.rawValue)
                        .font(.headline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(budget.periodLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(budget.amount))
                        .font(.subheadline.bold())
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Spent: \(formatAmount(spent))")
                        .font(.caption)
                        .foregroundColor(isOverBudget ? .red : .primary)
                    
                    Spacer()
                    
                    Text(isOverBudget ? "Over by \(formatAmount(spent - budget.amount))" : "Remaining: \(formatAmount(remaining))")
                        .font(.caption)
                        .foregroundColor(isOverBudget ? .red : .green)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 12)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressColor)
                            .frame(
                                width: min(geometry.size.width, geometry.size.width * CGFloat(percentage / 100)),
                                height: 12
                            )
                            .animation(.easeInOut(duration: 0.3), value: percentage)
                    }
                }
                .frame(height: 12)
                
                // Percentage text
                HStack {
                    Spacer()
                    Text("\(Int(percentage))%")
                        .font(.caption.bold())
                        .foregroundColor(progressColor)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOverBudget ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private var progressColor: Color {
        if isOverBudget {
            return .red
        } else if percentage > 80 {
            return .orange
        } else if percentage > 60 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
