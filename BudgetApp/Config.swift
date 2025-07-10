import Foundation

struct SupabaseConfig {
    static let url = "https://qmxyiqjwpgxucwhyckzg.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFteHlpcWp3cGd4dWN3aHlja3pnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMjI1MDUsImV4cCI6MjA2NzY5ODUwNX0.D5JhuPQjCtSFUMTmnWBHqikKJubxtL1nLIi4GRybj88"
}

struct APIConfig {
    // TODO: Replace with your actual Railway URL
    // Production Railway URL
    // Backend connections disabled - ready for new backend integration
    // Supabase endpoints for Plaid integration
    static let baseURL = SupabaseConfig.url
    
    static let createLinkTokenEndpoint = "\(baseURL)/functions/v1/create-link-token"
    static let exchangeTokenEndpoint = "\(baseURL)/functions/v1/exchange-token" 
    static let getTransactionsEndpoint = "\(baseURL)/functions/v1/get-transactions"
}

struct FinaAPIConfig {
    // Replace with your actual Fina Money API key from https://app.fina.money
    static let apiKey = "E4Y6Zq1txg3YLv"
    static let baseURL = "https://app.fina.money/api/resource/categorize"
    static let maxBatchSize = 100
    static let timeout: TimeInterval = 30
}