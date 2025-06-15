import SwiftUI
import UniformTypeIdentifiers

struct TransactionsView: View {
    @ObservedObject var transactionManager: TransactionManager
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if transactionManager.transactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    importButton
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
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Transactions Yet")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Import a CSV or Excel file to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
