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
            let data = try String(contentsOf: url)
            let rows = data.components(separatedBy: .newlines)
            
            print("📄 CSV Import: Found \(rows.count) rows")
            print("📄 First few rows of CSV:")
            for (index, row) in rows.prefix(5).enumerated() {
                print("📄 Row \(index + 1): '\(row)'")
            }
            
            // Process data rows (no header to skip based on your file format)
            var successCount = 0
            var errorCount = 0
            var errors: [String] = []
            var skippedCount = 0
            
            // Check if we have any data rows at all
            let dataRows = rows.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            print("📄 Data rows after filtering empty: \(dataRows.count)")
            
            if dataRows.isEmpty {
                handleError("CSV file appears to be empty.\n\nExpected format: Date,Amount,*,*,Description")
                return
            }
            
            // Process all rows (your CSV has no header)
            for (index, row) in rows.enumerated() where !row.trimmingCharacters(in: .whitespaces).isEmpty {
                do {
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
                    
                    // Skip rows with invalid or placeholder data
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
                    
                    // Try multiple date formats (prioritize MM/dd/yyyy for your file)
                    guard let date = parseDate(from: dateString) else {
                        let error = "Row \(index + 1): Invalid date format '\(dateString)'. Expected formats: MM/dd/yyyy, yyyy-MM-dd, dd/MM/yyyy"
                        errors.append(error)
                        errorCount += 1
                        continue
                    }
                    
                    // Clean amount string more aggressively
                    let cleanedAmountString = cleanAmountString(amountString)
                    print("📄 Row \(index + 1): Original amount '\(amountString)' -> Cleaned: '\(cleanedAmountString)'")
                    
                    guard let amount = Double(cleanedAmountString) else {
                        let error = "Row \(index + 1): Cannot parse amount '\(amountString)' (cleaned: '\(cleanedAmountString)')"
                        errors.append(error)
                        errorCount += 1
                        continue
                    }
                    
                    let predictedCategory = Transaction.predictCategory(from: description)
                    let transaction = Transaction(
                        date: date,
                        description: description,
                        amount: abs(amount), // Use absolute value since your amounts are already signed
                        category: predictedCategory,
                        type: amount < 0 ? .expense : .income
                    )
                    transactions.append(transaction)
                    successCount += 1
                    print("📄 ✅ Successfully created transaction: \(description) - $\(amount)")
                    
                } catch {
                    let errorMsg = "Row \(index + 1): \(error.localizedDescription)"
                    errors.append(errorMsg)
                    errorCount += 1
                }
            }
            
            print("📄 CSV Import Summary: Success: \(successCount), Errors: \(errorCount), Skipped: \(skippedCount)")
            
            // Show results
            if successCount > 0 {
                let message = "Successfully imported \(successCount) transactions" + 
                              (errorCount > 0 ? " (\(errorCount) errors)" : "") +
                              (skippedCount > 0 ? " (\(skippedCount) skipped)" : "")
                print("📄 CSV Import Result: \(message)")
                
                // Only show success message, no error dialog for successful imports
            } else {
                let errorDetails = errors.isEmpty ? "All rows were skipped or invalid." : errors.prefix(5).joined(separator: "\n")
                let summary = "Processed \(dataRows.count) data rows: \(successCount) successful, \(errorCount) errors, \(skippedCount) skipped"
                handleError("Failed to import any transactions.\n\n\(summary)\n\nErrors:\n\(errorDetails)\n\nYour CSV format: Date,Amount,*,*,Description\nExpected: MM/dd/yyyy,-4.50,*,*,Coffee Shop")
            }
            
        } catch {
            handleError("Error reading CSV file: \(error.localizedDescription)")
        }
    }
    
    private func cleanAmountString(_ amountString: String) -> String {
        var cleaned = amountString
        
        // Remove common currency symbols and formatting
        cleaned = cleaned.replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.replacingOccurrences(of: "€", with: "")
        cleaned = cleaned.replacingOccurrences(of: "£", with: "")
        cleaned = cleaned.replacingOccurrences(of: "¥", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        
        // Handle parentheses for negative amounts (accounting format)
        if cleaned.hasPrefix("(") && cleaned.hasSuffix(")") {
            cleaned = "-" + String(cleaned.dropFirst().dropLast())
        }
        
        // Remove any remaining non-numeric characters except decimal point and minus sign
        cleaned = cleaned.filter { char in
            char.isNumber || char == "." || char == "-"
        }
        
        // Handle multiple decimal points (keep only the last one)
        let parts = cleaned.components(separatedBy: ".")
        if parts.count > 2 {
            let wholePart = parts.dropLast().joined(separator: "")
            let decimalPart = parts.last ?? ""
            cleaned = wholePart + "." + decimalPart
        }
        
        // Handle multiple minus signs (keep only the first one)
        if cleaned.filter({ $0 == "-" }).count > 1 {
            let firstMinusIndex = cleaned.firstIndex(of: "-")
            let withoutMinus = cleaned.replacingOccurrences(of: "-", with: "")
            if let firstIndex = firstMinusIndex {
                cleaned = "-" + withoutMinus
            }
        }
        
        return cleaned
    }
    
    private func importExcel(from url: URL) {
        do {
            guard let file = try? XLSXFile(filepath: url.path) else {
                handleError("Unable to open Excel file")
                return
            }
            
            guard let workbook = try? file.parseWorkbooks().first else {
                handleError("Unable to read Excel workbook")
                return
            }
            
            guard let worksheetPaths = try? file.parseWorksheetPathsAndNames(workbook: workbook) else {
                handleError("Unable to read Excel worksheets")
                return
            }
            
            guard let path = worksheetPaths.first?.path else {
                handleError("No worksheets found in Excel file")
                return
            }
            
            guard let worksheet = try? file.parseWorksheet(at: path) else {
                handleError("Unable to parse worksheet")
                return
            }
            
            let sharedStrings = try? file.parseSharedStrings()
            
            var isFirstRow = true
            for row in worksheet.data?.rows ?? [] {
                if isFirstRow {
                    isFirstRow = false
                    continue
                }
                
                let rowNumber = row.reference
                guard let dateCells = try? worksheet.cells(atColumns: [ColumnReference("A")!], rows: [rowNumber]),
                      let descCells = try? worksheet.cells(atColumns: [ColumnReference("B")!], rows: [rowNumber]),
                      let amountCells = try? worksheet.cells(atColumns: [ColumnReference("C")!], rows: [rowNumber]),
                      let dateCell = dateCells.first,
                      let descCell = descCells.first,
                      let amountCell = amountCells.first else {
                    continue
                }
                
                let dateString = dateCell.value ?? ""
                let description = descCell.value ?? ""
                let amountString = amountCell.value ?? ""
                
                if let date = DateFormatter.standardDate.date(from: dateString),
                   let amount = Double(amountString) {
                    let predictedCategory = Transaction.predictCategory(from: description)
                    let transaction = Transaction(
                        date: date,
                        description: description,
                        amount: amount,
                        category: predictedCategory,
                        type: amount < 0 ? .expense : .income
                    )
                    transactions.append(transaction)
                }
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
        
        // Add the last column
        columns.append(currentColumn)
        
        // Clean up quotes from columns
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
            DateFormatter.usDate,             // MM/dd/yyyy (prioritize for your CSV)
            DateFormatter.shortDate,          // M/d/yy
            DateFormatter.standardDate,       // yyyy-MM-dd
            DateFormatter.euroDate,           // dd/MM/yyyy
            DateFormatter.usDateDashes,       // MM-dd-yyyy
            DateFormatter.euroDateDashes,     // dd-MM-yyyy
            DateFormatter.iso8601Short        // yyyy-MM-dd (ISO format)
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
        }
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
