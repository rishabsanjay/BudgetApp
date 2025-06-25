import SwiftUI
import UniformTypeIdentifiers
import LinkKit

struct TransactionsView: View {
    @ObservedObject var transactionManager: TransactionManager
    @State private var searchText = ""
    @State private var showingPlaidLink = false
    @State private var isLoadingPlaidData = false
    @State private var plaidStatusMessage = ""
    @State private var selectedCategory: TransactionCategory?
    
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
                        .background(
                            LinearGradient(
                                colors: [Color(.systemBackground), Color(.systemGray6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            transactionManager.showingFileImporter = true
                        } label: {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        
                        Button {
                            Task {
                                await generateLinkTokenAndConnect()
                            }
                        } label: {
                            if isLoadingLinkToken {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "building.columns.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)
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
                        color: categoryColor(for: category),
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
                .tint(.white)
            
            Text(plaidStatusMessage.isEmpty ? "Loading transactions..." : plaidStatusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("Welcome to Budget Tracker")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Start tracking your finances by importing transactions or connecting your bank account")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, 32)
            
            VStack(spacing: 16) {
                Button {
                    transactionManager.showingFileImporter = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Import File")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button {
                    Task {
                        await generateLinkTokenAndConnect()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Connect Bank Account")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 32)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16, weight: .semibold))
                    Text("Pro Tip")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("When connecting your bank account:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Text("Use phone:")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("(415) 555-0015")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.05), Color.yellow.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(12)
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
                        ModernTransactionRow(transaction: transaction) { category in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                transactionManager.categorizeTransaction(transaction, as: category)
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
        return grouped.sorted { $0.key > $1.key }
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
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    private func categoryColor(for category: TransactionCategory) -> Color {
        switch category {
        case .groceries: return .green
        case .utilities: return .yellow
        case .entertainment: return .purple
        case .transportation: return .blue
        case .dining: return .orange
        case .shopping: return .pink
        case .healthcare: return .red
        case .housing: return .brown
        case .education: return .cyan
        case .uncategorized: return .gray
        }
    }
    
    private func fetchTransactionsFromPlaid(publicToken: String) async throws {
        await MainActor.run {
            plaidStatusMessage = "Exchanging tokens..."
        }
        
        let exchangeURL = URL(string: APIConfig.exchangeTokenEndpoint)!
        var exchangeRequest = URLRequest(url: exchangeURL)
        exchangeRequest.httpMethod = "POST"
        exchangeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let exchangeBody = ["public_token": publicToken]
        exchangeRequest.httpBody = try JSONSerialization.data(withJSONObject: exchangeBody)
        
        let (exchangeData, exchangeUrlResponse) = try await URLSession.shared.data(for: exchangeRequest)

        guard let httpExchangeResponse = exchangeUrlResponse as? HTTPURLResponse, httpExchangeResponse.statusCode == 200 else {
            let statusCode = (exchangeUrlResponse as? HTTPURLResponse)?.statusCode ?? -1
            let errorData = String(data: exchangeData, encoding: .utf8) ?? "No error data"
            print("Exchange token failed. Status: \(statusCode). Data: \(errorData)")
            throw NSError(domain: "PlaidError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to exchange public token. Server said: \(errorData)"])
        }

        let exchangeResponse = try JSONSerialization.jsonObject(with: exchangeData) as? [String: Any]
        
        guard let accessToken = exchangeResponse?["access_token"] as? String else {
            print("Access token not found in exchange response: \(String(describing: exchangeResponse))")
            throw NSError(domain: "PlaidError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token received"])
        }
        
        await MainActor.run {
            plaidStatusMessage = "Fetching your transactions..."
        }
        
        let transactionsURLString = "\(APIConfig.getTransactionsEndpoint)?access_token=\(accessToken)"
        guard let transactionsURL = URL(string: transactionsURLString) else {
            throw NSError(domain: "PlaidError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid transactions URL"])
        }
        
        let (transactionsData, transactionsUrlResponse) = try await URLSession.shared.data(for: URLRequest(url: transactionsURL))

        guard let httpTransactionsResponse = transactionsUrlResponse as? HTTPURLResponse, httpTransactionsResponse.statusCode == 200 else {
            let statusCode = (transactionsUrlResponse as? HTTPURLResponse)?.statusCode ?? -1
            let errorData = String(data: transactionsData, encoding: .utf8) ?? "No error data"
            print("Get transactions failed. Status: \(statusCode). Data: \(errorData)")
            throw NSError(domain: "PlaidError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to get transactions. Server said: \(errorData)"])
        }
        
        print("Raw transaction data: \(String(data: transactionsData, encoding: .utf8) ?? "No data")")
        
        let responseData = try JSONSerialization.jsonObject(with: transactionsData) as? [String: Any] ?? [:]
        let plaidTransactions = responseData["transactions"] as? [[String: Any]] ?? []
        
        let appTransactions = plaidTransactions.compactMap { dict -> Transaction? in
            guard let dateStr = dict["date"] as? String,
                  let amount = dict["amount"] as? Double,
                  let name = dict["name"] as? String,
                  let _ = dict["transaction_id"] as? String
            else {
                print("Skipping transaction due to missing fields: \(dict)")
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
        
        await MainActor.run {
            if appTransactions.isEmpty && !plaidTransactions.isEmpty {
                 plaidStatusMessage = "Fetched Plaid transactions, but failed to map them to app model."
                 transactionManager.errorMessage = "Could not process transactions from Plaid."
                 transactionManager.showError = true
            } else if appTransactions.isEmpty {
                plaidStatusMessage = "No transactions found."
                transactionManager.errorMessage = "No transactions found in the connected accounts. For sandbox, use 'user_transactions_dynamic' / 'password' to see sample data."
                transactionManager.showError = true
            } else {
                plaidStatusMessage = "Successfully loaded \(appTransactions.count) transactions!"
                transactionManager.transactions.append(contentsOf: appTransactions)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
            let linkTokenURL = URL(string: APIConfig.createLinkTokenEndpoint)!
            var request = URLRequest(url: linkTokenURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let errorData = String(data: data, encoding: .utf8) ?? "No error data"
                throw NSError(domain: "LinkTokenError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create link token. Server said: \(errorData)"])
            }
            
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let token = responseData?["link_token"] as? String else {
                throw NSError(domain: "LinkTokenError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No link token received"])
            }
            
            await MainActor.run {
                self.linkToken = token
                isLoadingLinkToken = false
                showingPlaidLink = true
            }
            
        } catch {
            await MainActor.run {
                isLoadingLinkToken = false
                transactionManager.errorMessage = "Failed to generate link token: \(error.localizedDescription)"
                transactionManager.showError = true
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, icon: String, color: Color = .blue, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        color.opacity(0.1)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
            .cornerRadius(20)
            .shadow(
                color: isSelected ? color.opacity(0.3) : .clear,
                radius: isSelected ? 4 : 0,
                x: 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernTransactionRow: View {
    let transaction: Transaction
    let onCategorySelect: (TransactionCategory) -> Void
    @State private var showingCategoryPicker = false
    
    var body: some View {
        HStack(spacing: 16) {
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
                
                Image(systemName: transaction.category.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(categoryColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: transaction.category.icon)
                                .font(.system(size: 10, weight: .medium))
                            Text(transaction.category.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatAmount(transaction.amount, type: transaction.type))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.type == .expense ? .red : .green)
                
                Text(transaction.type.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
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
    
    var categoryColor: Color {
        switch transaction.category {
        case .groceries: return .green
        case .utilities: return .yellow
        case .entertainment: return .purple
        case .transportation: return .blue
        case .dining: return .orange
        case .shopping: return .pink
        case .healthcare: return .red
        case .housing: return .brown
        case .education: return .cyan
        case .uncategorized: return .gray
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
