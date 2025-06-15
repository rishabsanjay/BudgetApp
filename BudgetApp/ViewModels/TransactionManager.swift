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
            
            // Skip header row
            for row in rows.dropFirst() where !row.isEmpty {
                let columns = row.components(separatedBy: ",")
                if columns.count >= 3 {
                    if let date = DateFormatter.standardDate.date(from: columns[0].trimmingCharacters(in: .whitespaces)),
                       let amount = Double(columns[2].trimmingCharacters(in: .whitespaces)) {
                        let description = columns[1].trimmingCharacters(in: .whitespaces)
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
            }
        } catch {
            handleError("Error reading CSV: \(error.localizedDescription)")
        }
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
}
