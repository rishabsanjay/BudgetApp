import SwiftUI

struct HomeView: View {
    @StateObject private var transactionManager = TransactionManager()
    @StateObject private var budgetManager = BudgetManager()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
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
                
                // Custom tab bar
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
    }
}

// Beautiful custom tab bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabNamespace
    
    private let tabs = [
        TabItem(title: "Transactions", icon: "list.bullet", selectedIcon: "list.bullet"),
        TabItem(title: "Budget", icon: "chart.pie", selectedIcon: "chart.pie.fill"),
        TabItem(title: "Analytics", icon: "chart.bar", selectedIcon: "chart.bar.fill")
    ]
    
    var body: some View {
        HStack {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarButton(
                    tab: tabs[index],
                    isSelected: selectedTab == index,
                    namespace: tabNamespace
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct TabItem {
    let title: String
    let icon: String
    let selectedIcon: String
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 32)
                            .matchedGeometryEffect(id: "selectedTab", in: namespace)
                    }
                    
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                Text(tab.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// Budget Dashboard View for better organization
struct BudgetDashboardView: View {
    @ObservedObject var budgetManager: BudgetManager
    @ObservedObject var transactionManager: TransactionManager
    @State private var showingBudgetSetup = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header section
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Budget Overview")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Track your spending goals")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            showingBudgetSetup = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Budget cards
                    if budgetManager.activeBudgets.isEmpty {
                        EmptyBudgetState {
                            showingBudgetSetup = true
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ForEach(budgetManager.activeBudgets) { budget in
                            EnhancedBudgetProgressCard(
                                budget: budget,
                                transactions: transactionManager.transactions,
                                budgetManager: budgetManager
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer(minLength: 100) // Space for tab bar
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingBudgetSetup) {
            BudgetSetupView(budgetManager: budgetManager)
        }
    }
}

// Empty budget state component
struct EmptyBudgetState: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("Create Your First Budget")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Set spending limits for different categories to stay on track with your financial goals")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Create Budget")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}
