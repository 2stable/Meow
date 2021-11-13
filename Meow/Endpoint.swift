import Foundation

enum Endpoint {
    struct Response: Codable {
        let active_subscribers_count: Int
        let active_trials_count: Int
        let active_users_count: Int
        let installs_count: Int
        let mrr: Double
        let revenue: Double
    }

    struct Error: Decodable {
        let code: Int
        let message: String
    }
}
