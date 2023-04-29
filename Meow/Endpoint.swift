import Foundation

enum Endpoint {
    struct Overview: Codable {
        struct Metrics: Codable {
            let id: String
            let value: Double
        }
        
        let metrics: [Metrics]
        
        func activeSubscriptions() -> Int {
            return Int(self.metrics.first(where: { $0.id == "active_subscriptions" })?.value ?? 0)
        }
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
        func hash(into hasher: inout Hasher) {
            hasher.combine(self.id)
        }
        
        let name: String
        let id: String
    }
}
