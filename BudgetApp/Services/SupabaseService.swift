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
    
    // MARK: - Plaid Integration Functions
    
    func createLinkToken() async throws -> String {
        guard let url = URL(string: "https://qmxyiqjwpgxucwhyckzg.functions.supabase.co/create-link-token") else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        
        // Empty body for POST request
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode): \(errorString)"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["link_token"] as? String else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No link_token in response"])
        }

        return token
    }
    
    func exchangeToken(publicToken: String) async throws -> String {
        guard let url = URL(string: "https://qmxyiqjwpgxucwhyckzg.functions.supabase.co/exchange-token") else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ["public_token": publicToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode): \(errorString)"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let accessToken = json?["access_token"] as? String else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access_token in response"])
        }

        return accessToken
    }
    
    func getTransactions(accessToken: String) async throws -> [[String: Any]] {
        guard let url = URL(string: "https://qmxyiqjwpgxucwhyckzg.functions.supabase.co/get-transactions") else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ["access_token": accessToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode): \(errorString)"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let transactions = json?["transactions"] as? [[String: Any]] else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No transactions in response"])
        }

        return transactions
    }
    
    // MARK: - Database Operations
    
    func saveTransaction(_ transaction: Transaction) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        struct TransactionData: Codable {
            let id: String
            let user_id: String
            let date: String
            let description: String
            let amount: Double
            let category: String
            let type: String
            let created_at: String
        }
        
        let transactionData = TransactionData(
            id: transaction.id,
            user_id: userId.uuidString,
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
        guard let userId = client.auth.currentUser?.id else {
            throw NSError(domain: "SupabaseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        struct SupabaseTransaction: Codable {
            let id: String
            let user_id: String
            let date: String
            let description: String
            let amount: Double
            let category: String
            let type: String
        }
        
        let response: [SupabaseTransaction] = try await client.database
            .from("transactions")
            .select()
            .eq("user_id", value: userId.uuidString)
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