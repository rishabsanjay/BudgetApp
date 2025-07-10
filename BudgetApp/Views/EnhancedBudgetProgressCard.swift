import SwiftUI

struct EnhancedBudgetProgressCard: View {
    let budget: Budget
    let transactions: [Transaction]
    let budgetManager: BudgetManager
    
    @State private var showingDetails = false
    
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
    
    private var categoryColor: Color {
        switch budget.category {
        case .groceries: return .green
        case .utilities: return .yellow
        case .entertainment: return .purple
        case .transportation: return .blue
        case .dining: return .orange
        case .shopping: return .pink
        case .healthcare: return .red
        case .housing: return .brown
        case .education: return .cyan
        case .transfers: return .indigo
        case .uncategorized: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            VStack(spacing: 16) {
                // Header with category info
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [categoryColor.opacity(0.2), categoryColor.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: budget.category.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(categoryColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(budget.category.rawValue)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(budget.periodLabel)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(remaining))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(isOverBudget ? .red : .green)
                        
                        Text("remaining")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress section
                VStack(spacing: 12) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: progressColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: min(geometry.size.width, geometry.size.width * CGFloat(percentage / 100)),
                                    height: 8
                                )
                                .animation(.easeInOut(duration: 0.5), value: percentage)
                        }
                    }
                    .frame(height: 8)
                    
                    // Spending breakdown
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Spent")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(spent))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("\(Int(percentage))%")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(isOverBudget ? .red : categoryColor)
                            
                            Text("of budget")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Budget")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(formatCurrency(budget.amount))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Status indicator
                if isOverBudget {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                        
                        Text("Over budget by \(formatCurrency(spent - budget.amount))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                } else if percentage > 80 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        
                        Text("Approaching budget limit")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [categoryColor.opacity(0.3), categoryColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: categoryColor.opacity(0.1), radius: 12, x: 0, y: 4)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingDetails.toggle()
            }
        }
    }
    
    private var progressColors: [Color] {
        if isOverBudget {
            return [.red.opacity(0.8), .red]
        } else if percentage > 80 {
            return [.orange.opacity(0.8), .orange]
        } else {
            return [categoryColor.opacity(0.8), categoryColor]
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
