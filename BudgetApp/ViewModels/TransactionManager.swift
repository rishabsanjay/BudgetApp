import Foundation
import CoreXLSX
import UniformTypeIdentifiers

@MainActor
class TransactionManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var selectedCategory: TransactionCategory?
    @Published var showingFileImporter = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let categoryService = CategoryService()
    private let smartCategorizationService = SmartCategorizationService()
    
    var smartService: SmartCategorizationService {
        return smartCategorizationService
    }

    func importFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            handleError("Cannot access file")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let fileExtension = url.pathExtension.lowercased()
        print("Importing file with extension: \(fileExtension)")
        
        switch fileExtension {
        case "csv":
            print("Importing CSV file")
            importCSV(from: url)
        case "xlsx":
            print("Importing Excel file")
            importExcel(from: url)
        default:
            handleError("Unsupported file format: \(fileExtension)")
        }
    }
    
    private func importCSV(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let content = String(data: data, encoding: .utf8) ?? ""
            let rows = content.components(separatedBy: .newlines)
            
            print("📄 CSV Import: Found \(rows.count) rows")
            print("📄 First few rows of CSV:")
            for (index, row) in rows.prefix(5).enumerated() {
                print("📄 Row \(index + 1): '\(row)'")
            }
            
            var successCount = 0
            var errorCount = 0
            var errors: [String] = []
            var skippedCount = 0
            var tempTransactions: [Transaction] = []
            
            let dataRows = rows.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            print("📄 Data rows after filtering empty: \(dataRows.count)")
            
            if dataRows.isEmpty {
                handleError("CSV file appears to be empty.\n\nExpected format: Date,Amount,*,*,Description")
                return
            }
            
            for (index, row) in rows.enumerated() where !row.trimmingCharacters(in: .whitespaces).isEmpty {
                let columns = parseCSVRow(row)
                print("📄 Processing Row \(index + 1): \(columns)")
                
                guard columns.count >= 5 else {
                    let error = "Row \(index + 1): Expected at least 5 columns, found \(columns.count). Columns: \(columns)"
                    errors.append(error)
                    errorCount += 1
                    continue
                }
                
                let dateString = columns[0].trimmingCharacters(in: .whitespaces)
                let amountString = columns[1].trimmingCharacters(in: .whitespaces)
                let description = columns[4].trimmingCharacters(in: .whitespaces)
                
                print("📄 Row \(index + 1) parsed: Date='\(dateString)', Amount='\(amountString)', Description='\(description)'")
                
                if amountString.isEmpty || amountString == "*" || amountString == "N/A" || amountString == "-" || amountString == "TBD" {
                    print("📄 Skipping Row \(index + 1): Empty or placeholder amount '\(amountString)'")
                    skippedCount += 1
                    continue
                }
                
                if description.isEmpty || description == "*" || description == "N/A" || description == "-" {
                    print("📄 Skipping Row \(index + 1): Empty or placeholder description '\(description)'")
                    skippedCount += 1
                    continue
                }
                
                if dateString.isEmpty || dateString == "*" || dateString == "N/A" || dateString == "-" {
                    print("📄 Skipping Row \(index + 1): Empty or placeholder date '\(dateString)'")
                    skippedCount += 1
                    continue
                }
                
                guard let date = parseDate(from: dateString) else {
                    let error = "Row \(index + 1): Invalid date format '\(dateString)'. Expected formats: MM/dd/yyyy, yyyy-MM-dd, dd/MM/yyyy"
                    errors.append(error)
                    errorCount += 1
                    continue
                }
                
                let cleanedAmountString = cleanAmountString(amountString)
                print("📄 Row \(index + 1): Original amount '\(amountString)' -> Cleaned: '\(cleanedAmountString)'")
                
                guard let amount = Double(cleanedAmountString) else {
                    let error = "Row \(index + 1): Cannot parse amount '\(amountString)' (cleaned: '\(cleanedAmountString)')"
                    errors.append(error)
                    errorCount += 1
                    continue
                }
                
                let transaction = Transaction(
                    date: date,
                    description: description,
                    amount: abs(amount),
                    category: .uncategorized,
                    type: amount < 0 ? .expense : .income
                )
                tempTransactions.append(transaction)
                successCount += 1
                print("📄 ✅ Successfully created transaction: \(description) - $\(amount)")
            }
            
            Task {
                print("🔗 Testing Fina Money API connection...")
                let apiIsHealthy = await smartCategorizationService.testFinaAPIConnection()
                print("🔗 Fina API health: \(apiIsHealthy ? "✅ Connected" : "❌ Unavailable")")
                
                let enhancedTransactions = await smartCategorizationService.categorizeTransactions(tempTransactions)
                
                let categorizedCount = enhancedTransactions.filter { $0.category != .uncategorized }.count
                let categorizationRate = Double(categorizedCount) / Double(enhancedTransactions.count) * 100
                
                let apiStats = smartCategorizationService.getAccuracyStats()
                let apiSuccessRate = apiStats.apiSuccessRate * 100
                
                print("📊 Smart Categorization Results:")
                print("📊 Total transactions: \(enhancedTransactions.count)")
                print("📊 Categorized: \(categorizedCount)")
                print("📊 Uncategorized: \(enhancedTransactions.count - categorizedCount)")
                print("📊 Success rate: \(String(format: "%.1f", categorizationRate))%")
                print("📊 API success rate: \(String(format: "%.1f", apiSuccessRate))%")
                print("📊 Review queue: \(smartCategorizationService.reviewQueue.count) items")
                
                self.transactions.append(contentsOf: enhancedTransactions)
                
                print("📄 CSV Import Summary: Success: \(successCount), Errors: \(errorCount), Skipped: \(skippedCount)")
                
                if successCount > 0 {
                    let reviewCount = smartCategorizationService.reviewQueue.count
                    let message = "Successfully imported \(successCount) transactions" +
                                  (errorCount > 0 ? " (\(errorCount) errors)" : "") +
                                  (skippedCount > 0 ? " (\(skippedCount) skipped)" : "") +
                                  "\n\n🤖 Fina Money API Categorization:" +
                                  "\n• \(categorizedCount)/\(enhancedTransactions.count) categorized (\(String(format: "%.1f", categorizationRate))%)" +
                                  "\n• API success rate: \(String(format: "%.1f", apiSuccessRate))%" +
                                  (reviewCount > 0 ? "\n• \(reviewCount) transactions flagged for review" : "\n• All transactions categorized with high confidence!") +
                                  (apiIsHealthy ? "" : "\n⚠️ API unavailable - used fallback categorization")
                    print("📄 CSV Import Result: \(message)")
                } else {
                    let errorDetails = errors.isEmpty ? "All rows were skipped or invalid." : errors.prefix(5).joined(separator: "\n")
                    let summary = "Processed \(dataRows.count) data rows: \(successCount) successful, \(errorCount) errors, \(skippedCount) skipped"
                    handleError("Failed to import any transactions.\n\n\(summary)\n\nErrors:\n\(errorDetails)\n\nYour CSV format: Date,Amount,*,*,Description\nExpected: MM/dd/yyyy,-4.50,*,*,Coffee Shop")
                }
            }
            
        } catch {
            handleError("Error reading CSV file: \(error.localizedDescription)")
        }
    }
    
    private func cleanAmountString(_ amountString: String) -> String {
        var cleaned = amountString
        
        cleaned = cleaned.replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.replacingOccurrences(of: "€", with: "")
        cleaned = cleaned.replacingOccurrences(of: "£", with: "")
        cleaned = cleaned.replacingOccurrences(of: "¥", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        
        if cleaned.hasPrefix("(") && cleaned.hasSuffix(")") {
            cleaned = "-" + String(cleaned.dropFirst().dropLast())
        }
        
        cleaned = cleaned.filter { char in
            char.isNumber || char == "." || char == "-"
        }
        
        let parts = cleaned.components(separatedBy: ".")
        if parts.count > 2 {
            let wholePart = parts.dropLast().joined(separator: "")
            let decimalPart = parts.last ?? ""
            cleaned = wholePart + "." + decimalPart
        }
        
        if cleaned.filter({ $0 == "-" }).count > 1 {
            let withoutMinus = cleaned.replacingOccurrences(of: "-", with: "")
            cleaned = "-" + withoutMinus
        }
        
        return cleaned
    }
    
    private func importExcel(from url: URL) {
        guard let file = XLSXFile(filepath: url.path) else {
            handleError("Unable to open Excel file")
            return
        }
        
        do {
            let workbooks = try file.parseWorkbooks()
            guard let workbook = workbooks.first else {
                handleError("Unable to read Excel workbook")
                return
            }
            
            let worksheetPaths = try file.parseWorksheetPathsAndNames(workbook: workbook)
            guard let path = worksheetPaths.first?.path else {
                handleError("No worksheets found in Excel file")
                return
            }
            
            let worksheet = try file.parseWorksheet(at: path)
            
            _ = try? file.parseSharedStrings()
            
            var isFirstRow = true
            var tempTransactions: [Transaction] = []
            
            for row in worksheet.data?.rows ?? [] {
                if isFirstRow {
                    isFirstRow = false
                    continue
                }
                
                let rowNumber = row.reference
                do {
                    let dateCells = try worksheet.cells(atColumns: [ColumnReference("A")!], rows: [rowNumber])
                    let descCells = try worksheet.cells(atColumns: [ColumnReference("B")!], rows: [rowNumber])
                    let amountCells = try worksheet.cells(atColumns: [ColumnReference("C")!], rows: [rowNumber])
                    
                    guard let dateCell = dateCells.first,
                          let descCell = descCells.first,
                          let amountCell = amountCells.first else {
                        continue
                    }
                    
                    let dateString = dateCell.value ?? ""
                    let description = descCell.value ?? ""
                    let amountString = amountCell.value ?? ""
                    
                    if let date = DateFormatter.standardDate.date(from: dateString),
                       let amount = Double(amountString) {
                        let transaction = Transaction(
                            date: date,
                            description: description,
                            amount: amount,
                            category: .uncategorized,
                            type: amount < 0 ? .expense : .income
                        )
                        tempTransactions.append(transaction)
                    }
                } catch {
                    continue
                }
            }
            
            Task {
                let enhancedTransactions = await smartCategorizationService.categorizeTransactions(tempTransactions)
                self.transactions.append(contentsOf: enhancedTransactions)
            }
            
        } catch {
            handleError("Error parsing Excel file: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func parseCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        var i = row.startIndex
        
        while i < row.endIndex {
            let char = row[i]
            
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }
            
            i = row.index(after: i)
        }
        
        columns.append(currentColumn)
        
        return columns.map { column in
            var cleaned = column.trimmingCharacters(in: .whitespaces)
            if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
                cleaned = String(cleaned.dropFirst().dropLast())
            }
            return cleaned
        }
    }
    
    private func parseDate(from dateString: String) -> Date? {
        let formatters = [
            DateFormatter.usDate,
            DateFormatter.shortDate,
            DateFormatter.standardDate,
            DateFormatter.euroDate,
            DateFormatter.usDateDashes,
            DateFormatter.euroDateDashes,
            DateFormatter.iso8601Short
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    func categorizeTransaction(_ transaction: Transaction, as category: TransactionCategory) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index].category = category
            
            smartCategorizationService.userCorrectedCategory(for: transaction, to: category)
        }
    }
    
    func enhanceAllCategorization() {
        Task {
            let enhancedTransactions = await smartCategorizationService.categorizeTransactions(transactions)
            await MainActor.run {
                self.transactions = enhancedTransactions
            }
        }
    }
    
    func getSmartCategorizationStats() -> AccuracyStats {
        return smartCategorizationService.getAccuracyStats()
    }
    
    func getCategorizationStats() -> (total: Int, categorized: Int, percentage: Double) {
        let total = transactions.count
        let categorized = transactions.filter { $0.category != .uncategorized }.count
        let percentage = total > 0 ? Double(categorized) / Double(total) * 100 : 0
        return (total: total, categorized: categorized, percentage: percentage)
    }
}

extension DateFormatter {
    static let standardDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let usDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()
    
    static let euroDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    static let usDateDashes: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        return formatter
    }()
    
    static let euroDateDashes: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()
    
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter
    }()
    
    static let iso8601Short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
