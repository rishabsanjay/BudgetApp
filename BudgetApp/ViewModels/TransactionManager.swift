import Foundation
import SwiftUI
import CoreXLSX

class TransactionManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var showingFileImporter = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let supabaseService = SupabaseService.shared
    
    init() {
        
    }
    
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        
        Task {
            do {
                try await supabaseService.saveTransaction(transaction)
            } catch {
                print("Failed to save transaction to Supabase: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save transaction: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func categorizeTransaction(_ transaction: Transaction, as category: TransactionCategory) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index].category = category
        }
    }
    
    func enhanceAllCategorization() {
        for i in transactions.indices {
            let transaction = transactions[i]
            let (predictedCategory, _) = Transaction.predictCategoryWithConfidence(
                from: transaction.description,
                amount: transaction.amount
            )
            
            if transaction.category == .uncategorized {
                transactions[i].category = predictedCategory
            }
        }
    }
    
    func getCategorizationStats() -> (total: Int, categorized: Int, accuracy: Double) {
        let total = transactions.count
        let categorized = transactions.filter { $0.category != .uncategorized }.count
        let accuracy = total > 0 ? Double(categorized) / Double(total) * 100 : 0
        
        return (total: total, categorized: categorized, accuracy: accuracy)
    }
    
    func importFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Unable to access file"
            showError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let pathExtension = url.pathExtension.lowercased()
            var importedTransactions: [Transaction] = []
            
            if pathExtension == "csv" {
                importedTransactions = try importCSV(from: url)
            } else if pathExtension == "xlsx" {
                importedTransactions = try importXLSX(from: url)
            } else {
                throw ImportError.unsupportedFormat
            }
            
            let newTransactions = importedTransactions.filter { importedTransaction in
                !transactions.contains { existingTransaction in
                    existingTransaction.date == importedTransaction.date &&
                    existingTransaction.description == importedTransaction.description &&
                    abs(existingTransaction.amount - importedTransaction.amount) < 0.01
                }
            }
            
            if newTransactions.isEmpty {
                errorMessage = "No new transactions found in the file"
                showError = true
                return
            }
            
            transactions.append(contentsOf: newTransactions)
            
            Task {
                do {
                    try await supabaseService.saveTransactions(newTransactions)
                } catch {
                    print("Failed to save imported transactions to Supabase: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Transactions imported locally but failed to sync with cloud: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func importCSV(from url: URL) throws -> [Transaction] {
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines)
        
        guard lines.count > 1 else {
            throw ImportError.invalidFormat
        }
        
        let headerLine = lines[0].lowercased()
        let dateColumnIndex = findColumnIndex(for: ["date", "transaction date", "posted date"], in: headerLine)
        let descriptionColumnIndex = findColumnIndex(for: ["description", "memo", "payee", "transaction", "merchant"], in: headerLine)
        let amountColumnIndex = findColumnIndex(for: ["amount", "debit", "credit", "transaction amount"], in: headerLine)
        
        guard dateColumnIndex != -1, descriptionColumnIndex != -1, amountColumnIndex != -1 else {
            throw ImportError.missingColumns
        }
        
        var transactions: [Transaction] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            
            let columns = parseCSVLine(line)
            
            guard columns.count > max(dateColumnIndex, descriptionColumnIndex, amountColumnIndex) else {
                continue
            }
            
            let dateString = columns[dateColumnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let description = columns[descriptionColumnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let amountString = columns[amountColumnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !dateString.isEmpty, !description.isEmpty, !amountString.isEmpty else {
                continue
            }
            
            if let date = parseDate(from: dateString),
               let amount = Double(amountString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                
                let predictedCategory = Transaction.predictCategory(from: description)
                let type: TransactionType = amount < 0 ? .expense : .income
                
                let transaction = Transaction(
                    date: date,
                    description: description,
                    amount: abs(amount),
                    category: predictedCategory,
                    type: type
                )
                
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    private func importXLSX(from url: URL) throws -> [Transaction] {
        guard let file = XLSXFile(filepath: url.path) else {
            throw ImportError.invalidFormat
        }
        
        let workbook = try file.parseWorkbooks().first
        let worksheetPaths = try file.parseWorksheetPathsAndNames(workbook: workbook!)
        
        guard let firstWorksheetPath = worksheetPaths.first?.path else {
            throw ImportError.invalidFormat
        }
        
        let worksheet = try file.parseWorksheet(at: firstWorksheetPath)
        let sharedStrings = try file.parseSharedStrings()
        
        var transactions: [Transaction] = []
        let rows = worksheet.data?.rows ?? []
        
        guard rows.count > 1 else {
            throw ImportError.invalidFormat
        }
        
        // Parse header row
        let headerRow = rows[0]
        let headerValues = headerRow.cells.compactMap { cell in
            if let sharedStrings = sharedStrings {
                return cell.stringValue(sharedStrings)?.lowercased()
            } else {
                return cell.value?.lowercased()
            }
        }
        
        let dateColumnIndex = findColumnIndex(for: ["date", "transaction date", "posted date"], in: headerValues.joined(separator: ","))
        let descriptionColumnIndex = findColumnIndex(for: ["description", "memo", "payee", "transaction", "merchant"], in: headerValues.joined(separator: ","))
        let amountColumnIndex = findColumnIndex(for: ["amount", "debit", "credit", "transaction amount"], in: headerValues.joined(separator: ","))
        
        guard dateColumnIndex != -1, descriptionColumnIndex != -1, amountColumnIndex != -1 else {
            throw ImportError.missingColumns
        }
        
        for i in 1..<rows.count {
            let row = rows[i]
            let cells = row.cells
            
            guard cells.count > max(dateColumnIndex, descriptionColumnIndex, amountColumnIndex) else {
                continue
            }
            
            let dateString: String
            let description: String
            let amountString: String
            
            if let sharedStrings = sharedStrings {
                dateString = cells[dateColumnIndex].stringValue(sharedStrings) ?? ""
                description = cells[descriptionColumnIndex].stringValue(sharedStrings) ?? ""
                amountString = cells[amountColumnIndex].stringValue(sharedStrings) ?? ""
            } else {
                dateString = cells[dateColumnIndex].value ?? ""
                description = cells[descriptionColumnIndex].value ?? ""
                amountString = cells[amountColumnIndex].value ?? ""
            }
            
            guard !dateString.isEmpty, !description.isEmpty, !amountString.isEmpty else {
                continue
            }
            
            if let date = parseDate(from: dateString),
               let amount = Double(amountString.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                
                let predictedCategory = Transaction.predictCategory(from: description)
                let type: TransactionType = amount < 0 ? .expense : .income
                
                let transaction = Transaction(
                    date: date,
                    description: description,
                    amount: abs(amount),
                    category: predictedCategory,
                    type: type
                )
                
                transactions.append(transaction)
            }
        }
        
        return transactions
    }
    
    private func findColumnIndex(for keywords: [String], in header: String) -> Int {
        let columns = header.components(separatedBy: ",")
        
        for (index, column) in columns.enumerated() {
            let cleanColumn = column.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if keywords.contains(where: { cleanColumn.contains($0) }) {
                return index
            }
        }
        
        return -1
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        
        columns.append(currentColumn)
        return columns
    }
    
    private func parseDate(from string: String) -> Date? {
        let formatters = [
            DateFormatter().then { $0.dateFormat = "yyyy-MM-dd" },
            DateFormatter().then { $0.dateFormat = "MM/dd/yyyy" },
            DateFormatter().then { $0.dateFormat = "dd/MM/yyyy" },
            DateFormatter().then { $0.dateFormat = "MM-dd-yyyy" },
            DateFormatter().then { $0.dateFormat = "dd-MM-yyyy" },
            DateFormatter().then { $0.dateFormat = "M/d/yyyy" },
            DateFormatter().then { $0.dateFormat = "d/M/yyyy" }
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        return nil
    }
}

extension DateFormatter {
    func then(_ block: (DateFormatter) -> Void) -> DateFormatter {
        block(self)
        return self
    }
}

enum ImportError: LocalizedError {
    case unsupportedFormat
    case invalidFormat
    case missingColumns
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format. Please use CSV or XLSX files."
        case .invalidFormat:
            return "Invalid file format or corrupted file."
        case .missingColumns:
            return "Required columns (date, description, amount) not found in the file."
        }
    }
}