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
                if importedTransactions.isEmpty {
                    errorMessage = "No valid transactions found in the file. Please check the file format and ensure it contains date, description, and amount columns."
                } else {
                    errorMessage = "No new transactions found in the file. All transactions appear to be duplicates."
                }
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
            if let importError = error as? ImportError {
                errorMessage = importError.errorDescription
            } else {
                errorMessage = "Failed to import file: \(error.localizedDescription)"
            }
            showError = true
        }
    }
    
    private func importCSV(from url: URL) throws -> [Transaction] {
        let content = try String(contentsOf: url)
        let lines = content.components(separatedBy: .newlines)
        
        guard lines.count > 0 else {
            throw ImportError.invalidFormat
        }
        
        let firstLine = lines[0].lowercased()
        let hasHeaders = firstLine.contains("date") || firstLine.contains("description") || firstLine.contains("amount") || firstLine.contains("transaction")
        
        let startIndex = hasHeaders ? 1 : 0
        let headerLine = hasHeaders ? firstLine : ""
        
        var dateColumnIndex = -1
        var descriptionColumnIndex = -1
        var amountColumnIndex = -1
        
        if hasHeaders {
            dateColumnIndex = findColumnIndex(for: [
                "date", "transaction date", "posted date", "post date", "trans date",
                "effective date", "value date", "booking date", "settlement date"
            ], in: headerLine)
            
            descriptionColumnIndex = findColumnIndex(for: [
                "description", "memo", "payee", "transaction", "merchant", "details",
                "reference", "narration", "transaction details", "counterparty",
                "beneficiary", "transaction description", "remarks", "purpose"
            ], in: headerLine)
            
            amountColumnIndex = findColumnIndex(for: [
                "amount", "debit", "credit", "transaction amount", "value", "sum",
                "total", "net amount", "gross amount", "balance change", "money"
            ], in: headerLine)
        } else {
            let sampleLines = lines.prefix(5).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            
            if let detectedColumns = detectColumnsFromData(sampleLines.map { $0 }) {
                dateColumnIndex = detectedColumns.dateIndex
                descriptionColumnIndex = detectedColumns.descriptionIndex
                amountColumnIndex = detectedColumns.amountIndex
            }
        }
        
        if dateColumnIndex == -1 || descriptionColumnIndex == -1 || amountColumnIndex == -1 {
            let firstDataLine = lines[startIndex < lines.count ? startIndex : 0]
            let columns = parseCSVLine(firstDataLine)
            
            if columns.count >= 3 {
                for (index, column) in columns.enumerated() {
                    if dateColumnIndex == -1 && isDateColumn(column) {
                        dateColumnIndex = index
                    } else if amountColumnIndex == -1 && isAmountColumn(column) {
                        amountColumnIndex = index
                    } else if descriptionColumnIndex == -1 && isDescriptionColumn(column) {
                        descriptionColumnIndex = index
                    }
                }
                
                if dateColumnIndex == -1 { dateColumnIndex = 0 }
                if columns.count >= 4 && descriptionColumnIndex == -1 { descriptionColumnIndex = 3 }
                else if descriptionColumnIndex == -1 { descriptionColumnIndex = 2 }
                if amountColumnIndex == -1 { amountColumnIndex = 1 }
            }
        }
        
        guard dateColumnIndex != -1, descriptionColumnIndex != -1, amountColumnIndex != -1 else {
            let sampleData = lines.prefix(3).joined(separator: "\n")
            throw ImportError.missingColumns("Could not detect columns automatically. Sample data:\n\(sampleData)\n\nTry ensuring your file has clear headers like 'Date', 'Description', 'Amount' or use a standard bank export format.")
        }
        
        var transactions: [Transaction] = []
        var successfulImports = 0
        var failedImports = 0
        
        for i in startIndex..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            
            let columns = parseCSVLine(line)
            
            guard columns.count > max(dateColumnIndex, descriptionColumnIndex, amountColumnIndex) else {
                failedImports += 1
                continue
            }
            
            let dateString = columns[dateColumnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let description = columns[descriptionColumnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let amountString = columns[amountColumnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !dateString.isEmpty, !description.isEmpty, !amountString.isEmpty else {
                failedImports += 1
                continue
            }
            
            if let date = parseDate(from: dateString),
               let amount = parseAmount(from: amountString) {
                
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
                successfulImports += 1
            } else {
                failedImports += 1
            }
        }
        
        if transactions.isEmpty {
            throw ImportError.noValidTransactions(successfulImports: successfulImports, failedImports: failedImports)
        }
        
        return transactions
    }
    
    private func detectColumnsFromData(_ lines: [String]) -> (dateIndex: Int, descriptionIndex: Int, amountIndex: Int)? {
        guard !lines.isEmpty else { return nil }
        
        let firstLine = lines[0]
        let columns = parseCSVLine(firstLine)
        
        guard columns.count >= 3 else { return nil }
        
        var dateIndex = -1
        var amountIndex = -1
        var descriptionIndex = -1
        
        for (index, column) in columns.enumerated() {
            let trimmed = column.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if dateIndex == -1 && isDateColumn(trimmed) {
                dateIndex = index
            } else if amountIndex == -1 && isAmountColumn(trimmed) {
                amountIndex = index
            } else if descriptionIndex == -1 && isDescriptionColumn(trimmed) {
                descriptionIndex = index
            }
        }
        
        if dateIndex != -1 && amountIndex != -1 && descriptionIndex != -1 {
            return (dateIndex, descriptionIndex, amountIndex)
        }
        
        return nil
    }
    
    private func isDateColumn(_ value: String) -> Bool {
        return parseDate(from: value) != nil
    }
    
    private func isAmountColumn(_ value: String) -> Bool {
        let cleaned = value.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "-")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Double(cleaned) != nil
    }
    
    private func isDescriptionColumn(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 3 && 
               parseDate(from: trimmed) == nil && 
               parseAmount(from: trimmed) == nil &&
               !trimmed.contains("***") 
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
        
        let headerRow = rows[0]
        let headerValues = headerRow.cells.compactMap { cell in
            if let sharedStrings = sharedStrings {
                return cell.stringValue(sharedStrings)?.lowercased()
            } else {
                return cell.value?.lowercased()
            }
        }
        
        let headerString = headerValues.joined(separator: ",")
        
        let dateColumnIndex = findColumnIndex(for: [
            "date", "transaction date", "posted date", "post date", "trans date",
            "effective date", "value date", "booking date", "settlement date"
        ], in: headerString)
        
        let descriptionColumnIndex = findColumnIndex(for: [
            "description", "memo", "payee", "transaction", "merchant", "details",
            "reference", "narration", "transaction details", "counterparty",
            "beneficiary", "transaction description", "remarks", "purpose"
        ], in: headerString)
        
        let amountColumnIndex = findColumnIndex(for: [
            "amount", "debit", "credit", "transaction amount", "value", "sum",
            "total", "net amount", "gross amount", "balance change", "money"
        ], in: headerString)
        
        guard dateColumnIndex != -1, descriptionColumnIndex != -1, amountColumnIndex != -1 else {
            throw ImportError.missingColumns("Available columns: \(headerValues.joined(separator: ", "))")
        }
        
        var successfulImports = 0
        var failedImports = 0
        
        for i in 1..<rows.count {
            let row = rows[i]
            let cells = row.cells
            
            guard cells.count > max(dateColumnIndex, descriptionColumnIndex, amountColumnIndex) else {
                failedImports += 1
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
                failedImports += 1
                continue
            }
            
            if let date = parseDate(from: dateString),
               let amount = parseAmount(from: amountString) {
                
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
                successfulImports += 1
            } else {
                failedImports += 1
            }
        }
        
        if transactions.isEmpty {
            throw ImportError.noValidTransactions(successfulImports: successfulImports, failedImports: failedImports)
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
                columns.append(currentColumn.trimmingCharacters(in: .whitespacesAndNewlines))
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
        }
        
        columns.append(currentColumn.trimmingCharacters(in: .whitespacesAndNewlines))
        return columns
    }
    
    private func parseDate(from string: String) -> Date? {
        let cleanString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let formatters = [
            DateFormatter().then { $0.dateFormat = "yyyy-MM-dd" },
            DateFormatter().then { $0.dateFormat = "yyyy-MM-dd HH:mm:ss" },
            DateFormatter().then { $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss" },
            DateFormatter().then { $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" },
            
            DateFormatter().then { $0.dateFormat = "MM/dd/yyyy" },
            DateFormatter().then { $0.dateFormat = "M/d/yyyy" },
            DateFormatter().then { $0.dateFormat = "MM/dd/yy" },
            DateFormatter().then { $0.dateFormat = "M/d/yy" },
            DateFormatter().then { $0.dateFormat = "MM-dd-yyyy" },
            DateFormatter().then { $0.dateFormat = "M-d-yyyy" },
            
            DateFormatter().then { $0.dateFormat = "dd/MM/yyyy" },
            DateFormatter().then { $0.dateFormat = "d/M/yyyy" },
            DateFormatter().then { $0.dateFormat = "dd/MM/yy" },
            DateFormatter().then { $0.dateFormat = "d/M/yy" },
            DateFormatter().then { $0.dateFormat = "dd-MM-yyyy" },
            DateFormatter().then { $0.dateFormat = "d-M-yyyy" },
            DateFormatter().then { $0.dateFormat = "dd.MM.yyyy" },
            DateFormatter().then { $0.dateFormat = "d.M.yyyy" },
            
            DateFormatter().then { $0.dateFormat = "MMM dd, yyyy" },
            DateFormatter().then { $0.dateFormat = "MMM d, yyyy" },
            DateFormatter().then { $0.dateFormat = "MMMM dd, yyyy" },
            DateFormatter().then { $0.dateFormat = "MMMM d, yyyy" },
            DateFormatter().then { $0.dateFormat = "dd MMM yyyy" },
            DateFormatter().then { $0.dateFormat = "d MMM yyyy" },
            DateFormatter().then { $0.dateFormat = "dd MMMM yyyy" },
            DateFormatter().then { $0.dateFormat = "d MMMM yyyy" }
        ]
        
        for formatter in formatters {
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: cleanString) {
                return date
            }
        }
        
        return nil
    }
    
    private func parseAmount(from string: String) -> Double? {
        let cleanString = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "(", with: "-")
            .replacingOccurrences(of: ")", with: "")
        
        return Double(cleanString)
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
    case missingColumns(String)
    case noValidTransactions(successfulImports: Int, failedImports: Int)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format. Please use CSV or XLSX files."
        case .invalidFormat:
            return "Invalid file format or corrupted file. Please ensure the file is properly formatted."
        case .missingColumns(let availableColumns):
            return "Could not find required columns (date, description, amount) in the file.\n\n\(availableColumns)\n\nPlease ensure your file has columns with recognizable names like 'Date', 'Description', 'Amount', 'Transaction Date', 'Memo', 'Payee', etc."
        case .noValidTransactions(let successfulImports, let failedImports):
            return "No valid transactions found in the file. Successfully processed: \(successfulImports), Failed: \(failedImports). Please check the file format and data."
        }
    }
}