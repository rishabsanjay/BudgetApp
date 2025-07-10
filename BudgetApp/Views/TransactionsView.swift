import SwiftUI
import UniformTypeIdentifiers
import LinkKit

struct TransactionsView: View {
    @ObservedObject var transactionManager: TransactionManager
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var searchText = ""
    @State private var showingPlaidLink = false
    @State private var isLoadingPlaidData = false
    @State private var plaidStatusMessage = ""
    @State private var selectedCategory: TransactionCategory?
    @State private var showingManualEntry = false
    
    @State private var linkToken: String? = nil
    @State private var isLoadingLinkToken = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBarSection
                
                if !TransactionCategory.allCases.isEmpty {
                    categoryFilterSection
                }
                
                if isLoadingPlaidData {
                    loadingBanner
                }
                
                if transactionManager.transactions.isEmpty && !isLoadingPlaidData {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            transactionManager.showingFileImporter = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Button {
                            Task {
                                await generateLinkTokenAndConnect()
                            }
                        } label: {
                            if isLoadingLinkToken {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.primary)
                            } else {
                                Image(systemName: "building.columns")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                        }
                        .disabled(isLoadingPlaidData || isLoadingLinkToken)
                    }
                }
            }
            .fileImporter(
                isPresented: $transactionManager.showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .spreadsheet],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    transactionManager.importFile(url: url)
                case .failure(let error):
                    transactionManager.errorMessage = error.localizedDescription
                    transactionManager.showError = true
                }
            }
            .alert("Error", isPresented: $transactionManager.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(transactionManager.errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualTransactionEntry(transactionManager: transactionManager)
            }
        }
        .sheet(isPresented: $showingPlaidLink) {
            if let token = self.linkToken {
                PlaidLinkView(
                    linkToken: token,
                    onSuccess: { publicToken in
                        print("Got public token: \(publicToken)")
                        showingPlaidLink = false
                        isLoadingPlaidData = true
                        plaidStatusMessage = "Connecting to your bank..."
                        Task {
                            do {
                                try await fetchTransactionsFromPlaid(publicToken: publicToken)
                            } catch {
                                print("Error fetching transactions: \(error)")
                                await MainActor.run {
                                    isLoadingPlaidData = false
                                    plaidStatusMessage = ""
                                    transactionManager.errorMessage = "Failed to fetch transactions: \(error.localizedDescription)"
                                    transactionManager.showError = true
                                }
                            }
                        }
                    },
                    onExit: {
                        showingPlaidLink = false
                    }
                )
            } else {
                Text("Error: Plaid Link token is missing.")
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { showingPlaidLink = false }
                    }
            }
        }
        .task {
            await loadTransactionsFromSupabase()
        }
    }
    
    private var searchBarSection: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search transactions", text: $searchText)
                    .font(.system(size: 16))
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryChip(
                    title: "All",
                    icon: "list.bullet",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }
                
                ForEach(TransactionCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }
    
    private var loadingBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
                .tint(.primary)
            
            Text(plaidStatusMessage.isEmpty ? "Loading transactions..." : plaidStatusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Transactions Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add transactions manually, import from a file, or connect your bank account")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 32)
            
            VStack(spacing: 12) {
                Button {
                    showingManualEntry = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                        Text("Add Transaction")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.primary)
                    .cornerRadius(8)
                }
                
                Button {
                    transactionManager.showingFileImporter = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .medium))
                        Text("Import File")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Button {
                    Task {
                        await generateLinkTokenAndConnect()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 16, weight: .medium))
                        Text("Connect Bank Account")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.vertical, 32)
    }
    
    private var transactionList: some View {
        List {
            ForEach(groupedTransactions, id: \.key) { group in
                Section {
                    ForEach(group.value) { transaction in
                        SimpleTransactionRow(transaction: transaction) { category in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                transactionManager.categorizeTransaction(transaction, as: category)
                                // Save category update to Supabase
                                Task {
                                    do {
                                        try await supabaseService.updateTransactionCategory(
                                            transactionId: transaction.id,
                                            category: category
                                        )
                                    } catch {
                                        print("Failed to update category in Supabase: \(error)")
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(group.key)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.leading, 16)
                        .padding(.bottom, 4)
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await refreshTransactions()
        }
    }
    
    private var groupedTransactions: [(key: String, value: [Transaction])] {
        let filtered = filteredTransactions
        let grouped = Dictionary(grouping: filtered) { transaction in
            DateFormatter.sectionHeader.string(from: transaction.date)
        }
        return grouped.sorted { first, second in
            let date1 = DateFormatter.sectionHeader.date(from: first.key) ?? Date.distantPast
            let date2 = DateFormatter.sectionHeader.date(from: second.key) ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private var filteredTransactions: [Transaction] {
        var transactions = transactionManager.transactions
        
        if let selectedCategory = selectedCategory {
            transactions = transactions.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            transactions = transactions.filter {
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return transactions.sorted(by: { $0.date > $1.date })
    }
    
    private func refreshTransactions() async {
        await loadTransactionsFromSupabase()
    }
    
    private func loadTransactionsFromSupabase() async {
        do {
            let transactions = try await supabaseService.loadTransactions()
            await MainActor.run {
                transactionManager.transactions = transactions
            }
        } catch {
            print("Failed to load transactions from Supabase: \(error)")
            await MainActor.run {
                transactionManager.errorMessage = "Failed to load transactions: \(error.localizedDescription)"
                transactionManager.showError = true
            }
        }
    }
    
    private func fetchTransactionsFromPlaid(publicToken: String) async throws {
        print("💳 Starting transaction fetch with public token: \(String(publicToken.prefix(20)))...")
        
        await MainActor.run {
            plaidStatusMessage = "Exchanging tokens..."
        }
        
        // Exchange public token for access token using Supabase
        let accessToken = try await supabaseService.exchangeToken(publicToken: publicToken)
        print("💳 Successfully received access token: \(String(accessToken.prefix(20)))...")
        
        await MainActor.run {
            plaidStatusMessage = "Fetching your transactions..."
        }
        
        // Get transactions using Supabase
        let plaidTransactions = try await supabaseService.getTransactions(accessToken: accessToken)
        print("💳 Parsed \(plaidTransactions.count) transactions from response")
        
        if plaidTransactions.isEmpty {
            print("💳 No transactions found in response")
        }
        
        let appTransactions = plaidTransactions.compactMap { dict -> Transaction? in
            guard let dateStr = dict["date"] as? String,
                  let amount = dict["amount"] as? Double,
                  let name = dict["name"] as? String,
                  let _ = dict["transaction_id"] as? String
            else {
                print("💳 Skipping transaction due to missing fields: \(dict)")
                return nil
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let transactionDate = dateFormatter.date(from: dateStr) ?? Date()
            
            let predictedCategory = Transaction.predictCategory(from: name)
            
            return Transaction(
                date: transactionDate,
                description: name,
                amount: amount,
                category: predictedCategory,
                type: amount > 0 ? .expense : .income
            )
        }
        
        print("💳 Successfully converted \(appTransactions.count) transactions to app format")
        
        // Save transactions to Supabase
        if !appTransactions.isEmpty {
            try await supabaseService.saveTransactions(appTransactions)
        }
        
        await MainActor.run {
            if appTransactions.isEmpty && !plaidTransactions.isEmpty {
                plaidStatusMessage = "⚠️ Fetched \(plaidTransactions.count) Plaid transactions, but failed to map them to app model."
                transactionManager.errorMessage = "Could not process transactions from Plaid. Raw data format may have changed."
                transactionManager.showError = true
            } else if appTransactions.isEmpty {
                plaidStatusMessage = "ℹ️ No transactions found in connected accounts."
                transactionManager.errorMessage = "No transactions found. For sandbox testing, try using credentials:\nUsername: user_transactions_dynamic\nPassword: password\n\nThis will provide sample transaction data."
                transactionManager.showError = true
            } else {
                plaidStatusMessage = "✅ Successfully loaded \(appTransactions.count) transactions!"
                transactionManager.transactions.append(contentsOf: appTransactions)
                print("💳 Added \(appTransactions.count) transactions to transaction manager")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isLoadingPlaidData = false
                if !transactionManager.showError {
                   plaidStatusMessage = ""
                }
            }
        }
    }
    
    private func generateLinkTokenAndConnect() async {
        await MainActor.run {
            isLoadingLinkToken = true
        }
        
        do {
            print("🔗 Starting link token generation...")
            
            let token = try await supabaseService.createLinkToken()
            print("🔗 Successfully received link token: \(String(token.prefix(20)))...")
            
            await MainActor.run {
                self.linkToken = token
                isLoadingLinkToken = false
                showingPlaidLink = true
            }
            
        } catch {
            print("🔗 Error generating link token: \(error)")
            await MainActor.run {
                isLoadingLinkToken = false
                
                let userMessage: String
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        userMessage = "No internet connection. Please check your network and try again."
                    case .timedOut:
                        userMessage = "Request timed out. Please check your internet connection and try again."
                    case .cannotConnectToHost:
                        userMessage = "Cannot connect to server. Please try again later."
                    default:
                        userMessage = "Network error: \(urlError.localizedDescription)"
                    }
                } else {
                    userMessage = error.localizedDescription
                }
                
                transactionManager.errorMessage = "Failed to generate link token: \(userMessage)"
                transactionManager.showError = true
            }
        }
    }
}

// Simplified category chip
struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    private var categoryColor: Color {
        switch title.lowercased() {
        case "groceries": return .green
        case "utilities": return .orange
        case "entertainment": return .purple
        case "transportation": return .blue
        case "dining": return .red
        case "shopping": return .pink
        case "healthcare": return .red
        case "housing": return .brown
        case "education": return .cyan
        case "transfers": return .indigo
        default: return .primary
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : categoryColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? categoryColor : Color(.systemGray6))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Simplified transaction row
struct SimpleTransactionRow: View {
    let transaction: Transaction
    let onCategorySelect: (TransactionCategory) -> Void
    @State private var showingCategoryPicker = false
    
    private var categoryColor: Color {
        switch transaction.category {
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
        HStack(spacing: 12) {
            Image(systemName: transaction.category.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(categoryColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        Text(transaction.category.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(categoryColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(formatAmount(transaction.amount, type: transaction.type))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(transaction.type == .expense ? .red : .green)
        }
        .padding(.vertical, 8)
        .confirmationDialog(
            "Select Category",
            isPresented: $showingCategoryPicker
        ) {
            ForEach(TransactionCategory.allCases, id: \.self) { category in
                Button(category.rawValue) {
                    onCategorySelect(category)
                }
            }
        }
    }
    
    private func formatAmount(_ amount: Double, type: TransactionType) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let valueToFormat = type == .expense ? -abs(amount) : abs(amount)
        return formatter.string(from: NSNumber(value: valueToFormat)) ?? "$0.00"
    }
}

extension DateFormatter {
    static let sectionHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
}