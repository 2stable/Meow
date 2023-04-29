import Foundation

enum Endpoint {
    struct Overview: Codable {
        let active_subscribers_count: Int
        let active_trials_count: Int
        let active_users_count: Int
        let installs_count: Int
        let mrr: Double
        let revenue: Double
    }
    
    struct Transaction: Codable, Hashable {
        let store_transaction_identifier: String
    }
    
    struct Transactions: Codable, Hashable {
        let transactions: [Transaction]
    }

    struct Error: Decodable {
        let code: Int
        let message: String
    }
    
    struct Response {
        let transactions: Set<Endpoint.Transaction>
        let overview: Endpoint.Overview
    }
    
    struct Project: Codable, Hashable {
        let name: String
        let id: String
    }
}
