import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
    
    // MARK: - Plaid Integration Functions (Placeholder - need Edge Functions)
    
    func createLinkToken() async throws -> String {
        // TODO: Implement when Supabase Edge Functions are set up
        throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Plaid integration requires Supabase Edge Functions to be deployed"])
    }
    
    func exchangeToken(publicToken: String) async throws -> String {
        // TODO: Implement when Supabase Edge Functions are set up
        throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Plaid integration requires Supabase Edge Functions to be deployed"])
    }
    
    func getTransactions(accessToken: String) async throws -> [[String: Any]] {
        // TODO: Implement when Supabase Edge Functions are set up
        throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Plaid integration requires Supabase Edge Functions to be deployed"])
    }
    
    // MARK: - Database Operations
    
    func saveTransaction(_ transaction: Transaction) async throws {
        struct TransactionData: Codable {
            let id: String
            let date: String
            let description: String
            let amount: Double
            let category: String
            let type: String
            let created_at: String
        }
        
        let transactionData = TransactionData(
            id: transaction.id,
            date: ISO8601DateFormatter().string(from: transaction.date),
            description: transaction.description,
            amount: transaction.amount,
            category: transaction.category.rawValue,
            type: transaction.type.rawValue,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client.database
            .from("transactions")
            .insert(transactionData)
            .execute()
    }
    
    func saveTransactions(_ transactions: [Transaction]) async throws {
        struct TransactionData: Codable {
            let id: String
            let date: String
            let description: String
            let amount: Double
            let category: String
            let type: String
            let created_at: String
        }
        
        let transactionsData = transactions.map { transaction in
            TransactionData(
                id: transaction.id,
                date: ISO8601DateFormatter().string(from: transaction.date),
                description: transaction.description,
                amount: transaction.amount,
                category: transaction.category.rawValue,
                type: transaction.type.rawValue,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
        }
        
        try await client.database
            .from("transactions")
            .insert(transactionsData)
            .execute()
    }
    
    func loadTransactions() async throws -> [Transaction] {
        struct SupabaseTransaction: Codable {
            let id: String
            let date: String
            let description: String
            let amount: Double
            let category: String
            let type: String
        }
        
        let response: [SupabaseTransaction] = try await client.database
            .from("transactions")
            .select()
            .order("date", ascending: false)
            .execute()
            .value
        
        var transactions: [Transaction] = []
        
        for supabaseTransaction in response {
            guard let category = TransactionCategory(rawValue: supabaseTransaction.category),
                  let type = TransactionType(rawValue: supabaseTransaction.type) else {
                print("Failed to parse transaction: \(supabaseTransaction)")
                continue
            }
            
            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: supabaseTransaction.date) ?? Date()
            
            let transaction = Transaction(
                id: supabaseTransaction.id,
                date: date,
                description: supabaseTransaction.description,
                amount: supabaseTransaction.amount,
                category: category,
                type: type
            )
            
            transactions.append(transaction)
        }
        
        return transactions
    }
    
    func updateTransactionCategory(transactionId: String, category: TransactionCategory) async throws {
        struct CategoryUpdate: Codable {
            let category: String
        }
        
        let updateData = CategoryUpdate(category: category.rawValue)
        
        try await client.database
            .from("transactions")
            .update(updateData)
            .eq("id", value: transactionId)
            .execute()
    }
    
    func deleteTransaction(transactionId: String) async throws {
        try await client.database
            .from("transactions")
            .delete()
            .eq("id", value: transactionId)
            .execute()
    }
}