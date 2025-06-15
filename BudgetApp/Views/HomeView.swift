import SwiftUI

struct HomeView: View {
    @StateObject private var transactionManager = TransactionManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TransactionsView(transactionManager: transactionManager)
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
                .tag(0)
            
            AnalyticsView(transactions: transactionManager.transactions)
                .tabItem {
                    Label("Analytics", systemImage: "chart.pie")
                }
                .tag(1)
        }
    }
}