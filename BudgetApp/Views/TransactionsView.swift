import SwiftUI
import UniformTypeIdentifiers
import LinkKit

struct TransactionsView: View {
    @ObservedObject var transactionManager: TransactionManager
    @State private var searchText = ""
    @State private var showingPlaidLink = false
    @State private var isLoadingPlaidData = false
    @State private var plaidStatusMessage = ""
    
    @State private var linkToken: String? = "link-sandbox-219318a0-6b5b-411e-a124-3be09c783a9e"
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoadingPlaidData {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(plaidStatusMessage.isEmpty ? "Loading transactions..." : plaidStatusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                if transactionManager.transactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    HStack {
                        importButton
                        
                        Button {
                            showingPlaidLink = true
                        } label: {
                            Label("Connect Bank", systemImage: "building.columns.fill")
                        }
                        .disabled(isLoadingPlaidData)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search transactions")
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
        }
        .sheet(isPresented: $showingPlaidLink) {
            if let linkToken = linkToken {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { publicToken in
                        print("Got public token: \(publicToken)")
                        showingPlaidLink = false
                        
                        // Show loading state
                        isLoadingPlaidData = true
                        plaidStatusMessage = "Connecting to your bank..."
                        
                        // Automatically fetch transactions after successful connection
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
            }
        }
    }
    
    // Function to fetch transactions from your backend
    private func fetchTransactionsFromPlaid(publicToken: String) async throws {
        await MainActor.run {
            plaidStatusMessage = "Exchanging tokens..."
        }
        
        // Step 1: Exchange public token for access token
        let exchangeURL = URL(string: "http://127.0.0.1:5000/exchange_token")!
        var exchangeRequest = URLRequest(url: exchangeURL)
        exchangeRequest.httpMethod = "POST"
        exchangeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let exchangeBody = ["public_token": publicToken]
        exchangeRequest.httpBody = try JSONSerialization.data(withJSONObject: exchangeBody)
        
        let (exchangeData, _) = try await URLSession.shared.data(for: exchangeRequest)
        let exchangeResponse = try JSONSerialization.jsonObject(with: exchangeData) as? [String: Any]
        
        guard let accessToken = exchangeResponse?["access_token"] as? String else {
            throw NSError(domain: "PlaidError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token received"])
        }
        
        await MainActor.run {
            plaidStatusMessage = "Fetching your transactions..."
        }
        
        // Step 2: Fetch transactions using access token
        let transactionsURL = URL(string: "http://127.0.0.1:5000/get_transactions?access_token=\(accessToken)")!
        let (transactionsData, _) = try await URLSession.shared.data(from: transactionsURL)
        
        print("Raw transaction data: \(String(data: transactionsData, encoding: .utf8) ?? "No data")")
        
        let responseData = try JSONSerialization.jsonObject(with: transactionsData) as? [String: Any] ?? [:]
        let plaidTransactions = responseData["transactions"] as? [[String: Any]] ?? []
        let totalTransactions = responseData["total_transactions"] as? Int ?? 0
        
        print("Parsed \(plaidTransactions.count) transactions from Plaid (total available: \(totalTransactions))")
        
        // Step 3: Convert Plaid transactions to your app's Transaction model and categorize them
        let appTransactions = plaidTransactions.compactMap { dict -> Transaction? in
            guard let date = dict["date"] as? String,
                  let amount = dict["amount"] as? Double,
                  let name = dict["name"] as? String else {
                return nil
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let transactionDate = dateFormatter.date(from: date) ?? Date()
            
            // Use your existing category prediction
            let predictedCategory = Transaction.predictCategory(from: name)
            
            return Transaction(
                date: transactionDate,
                description: name,
                amount: abs(amount), // Make amount positive, determine type separately
                category: predictedCategory,
                type: amount > 0 ? .expense : .income // Plaid uses positive for debits (expenses)
            )
        }
        
        await MainActor.run {
            if appTransactions.isEmpty {
                plaidStatusMessage = "No transactions found."
                transactionManager.errorMessage = """
                No transactions found in connected accounts.
                
                To see transaction data in Plaid's sandbox:
                1. When connecting, use these test credentials:
                   • Username: user_transactions_dynamic
                   • Password: password
                
                These special test accounts come with sample transaction data.
                """
                transactionManager.showError = true
            } else {
                plaidStatusMessage = "Successfully loaded \(appTransactions.count) transactions!"
            }
        }
        
        // Step 4: Add transactions to your transaction manager
        await MainActor.run {
            transactionManager.transactions.append(contentsOf: appTransactions)
            print("Added \(appTransactions.count) real transactions from Plaid")
            
            // Clear loading state after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isLoadingPlaidData = false
                plaidStatusMessage = ""
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Transactions Yet")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Import a CSV or Excel file or connect your bank to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("💡 For testing Plaid integration:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text("Use these test credentials:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Username: user_transactions_dynamic")
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text("• Password: password")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.leading, 8)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            importButton
                .padding()
        }
        .padding()
    }
    
    private var importButton: some View {
        Button {
            transactionManager.showingFileImporter = true
        } label: {
            Label("Import", systemImage: "square.and.arrow.down")
        }
    }
    
    private var transactionList: some View {
        List {
            ForEach(filteredTransactions) { transaction in
                TransactionRow(transaction: transaction) { category in
                    transactionManager.categorizeTransaction(transaction, as: category)
                }
            }
        }
    }
    
    private var filteredTransactions: [Transaction] {
        if searchText.isEmpty {
            return transactionManager.transactions
        }
        return transactionManager.transactions.filter {
            $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let onCategorySelect: (TransactionCategory) -> Void
    @State private var showingCategoryPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(transaction.description)
                        .font(.headline)
                    
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatAmount(transaction.amount))
                    .font(.headline)
                    .foregroundColor(transaction.type == .expense ? .red : .green)
            }
            
            Button {
                showingCategoryPicker = true
            } label: {
                HStack {
                    Image(systemName: transaction.category.icon)
                    Text(transaction.category.rawValue)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(transaction.category.color).opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
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
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: abs(amount))) ?? "$0.00"
    }
}
