import Foundation

struct APIConfig {
    // TODO: Replace with your actual Railway URL
    // Production Railway URL
    static let baseURL = "https://budgetapp-production-cf3a.up.railway.app"
    
    // Development URLs (commented out for production)
    // static let baseURL = "http://127.0.0.1:5000"
    
    static let createLinkTokenEndpoint = "\(baseURL)/create_link_token"
    static let exchangeTokenEndpoint = "\(baseURL)/exchange_token"
    static let getTransactionsEndpoint = "\(baseURL)/get_transactions"
}

struct FinaAPIConfig {
    // Replace with your actual Fina Money API key from https://app.fina.money
    static let apiKey = "E4Y6Zq1txg3YLv"
    static let baseURL = "https://app.fina.money/api/resource/categorize"
    static let maxBatchSize = 100
    static let timeout: TimeInterval = 30
}
