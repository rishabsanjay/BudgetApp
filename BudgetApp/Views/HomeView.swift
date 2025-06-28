import SwiftUI

struct HomeView: View {
    @StateObject private var transactionManager = TransactionManager()
    @StateObject private var budgetManager = BudgetManager()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            TabView(selection: $selectedTab) {
                TransactionsView(transactionManager: transactionManager)
                    .tag(0)
                
                BudgetDashboardView(
                    budgetManager: budgetManager,
                    transactionManager: transactionManager
                )
                .tag(1)
                
                AnalyticsView(transactions: transactionManager.transactions)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Simple tab bar
            MinimalTabBar(selectedTab: $selectedTab)
        }
        .background(Color(.systemBackground))
    }
}

// Clean minimal tab bar
struct MinimalTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs = [
        TabItem(title: "Transactions", icon: "dollarsign.circle"),
        TabItem(title: "Budget", icon: "chart.pie"),
        TabItem(title: "Analytics", icon: "chart.bar")
    ]
    
    var body: some View {
        HStack {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    selectedTab = index
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(selectedTab == index ? .primary : .secondary)
                        
                        Text(tabs[index].title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(selectedTab == index ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: -1)
        )
    }
}

struct TabItem {
    let title: String
    let icon: String
}

// Simplified Budget Dashboard
struct BudgetDashboardView: View {
    @ObservedObject var budgetManager: BudgetManager
    @ObservedObject var transactionManager: TransactionManager
    @State private var showingInlineCreation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Simple header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Budget")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Track your spending")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingInlineCreation.toggle()
                            }
                        } label: {
                            Image(systemName: showingInlineCreation ? "xmark" : "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Inline budget creation
                    if showingInlineCreation {
                        InlineBudgetCreation(budgetManager: budgetManager) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingInlineCreation = false
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                    }
                    
                    // Budget content
                    if budgetManager.activeBudgets.isEmpty && !showingInlineCreation {
                        SimpleEmptyBudgetState {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showingInlineCreation = true
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ForEach(budgetManager.activeBudgets) { budget in
                            SimpleBudgetCard(
                                budget: budget,
                                transactions: transactionManager.transactions,
                                budgetManager: budgetManager
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 80)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// Simple empty state
struct SimpleEmptyBudgetState: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Budgets Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Create your first budget to start tracking your spending")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: action) {
                Text("Create Budget")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.primary)
                    .cornerRadius(8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Simple budget card
struct SimpleBudgetCard: View {
    let budget: Budget
    let transactions: [Transaction]
    @ObservedObject var budgetManager: BudgetManager
    
    private var relevantTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions.filter { transaction in
            let isCurrentMonth = calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
            let isCurrentYear = calendar.isDate(transaction.date, equalTo: now, toGranularity: .year)
            let matchesCategory = transaction.category == budget.category
            
            return isCurrentMonth && isCurrentYear && matchesCategory && transaction.type == .expense
        }
    }
    
    private var totalSpent: Double {
        relevantTransactions.reduce(0) { $0 + $1.amount }
    }
    
    private var progress: Double {
        budget.amount > 0 ? min(totalSpent / budget.amount, 1.0) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: budget.category.icon)
                    .foregroundColor(.primary)
                Text(budget.category.rawValue)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack {
                Text("$\(String(format: "%.0f", totalSpent))")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                Text("of $\(String(format: "%.0f", budget.amount))")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progress > 0.9 ? .red : progress > 0.7 ? .orange : .primary))
            
            Text("\(String(format: "%.0f", (1 - progress) * 100))% remaining")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
