import Foundation
import RxSwift

struct Api {
    enum Error: Swift.Error {
        case accessDenied
    }
    
    private let storage: SecureStorage
    private let session: Session
    
    init(storage: SecureStorage, session: Session) {
        self.storage = storage
        self.session = session
    }
    
    private func request<T: Codable>(url: String) -> Single<T> {
        guard let token = self.storage.token() else {
            return .error(Error.accessDenied)
        }
    
        // If someone at RevenueCat has a better idea or there is another API that we can use
        // Please feel free to contact us, or open a PR
        guard !token.isExpired(), let url = URL(string: url) else {
            return .error(Error.accessDenied)
        }
        
        return self.session.json(request: .get(url: url, headers: [
            // swiftlint:disable:next force_https
            "X-Requested-With": "XMLHttpRequest",
            "Cookie": "rc_auth_token=\(token.value)"
        ]))
        .catch { error in
            if case Session.Error.code(_, let response) = error {
                let error = try JSONDecoder().decode(Endpoint.Error.self, from: response)
                
                if error.code == 7_224 {
                    return .error(Error.accessDenied)
                }
            }
            
            return .error(error)
        }
    }
    
    func overview(projects: [Endpoint.Project] = []) -> Single<Endpoint.Overview> {
        var components = URLComponents(string: "https://api.revenuecat.com/v1/developers/me/charts_v2/overview")

        if !projects.isEmpty {
            components?.queryItems = [.init(name: "app_uuid", value: projects.map { $0.id }.joined(separator: ","))]
        }

        // swiftlint:disable:next force_unwrapping
        return self.request(url: components!.url!.absoluteString)
    }
    
    func transactions(projects: [Endpoint.Project] = []) -> Single<Endpoint.Transactions> {
        var components = URLComponents(string: "https://api.revenuecat.com/v1/developers/me/transactions")

        if !projects.isEmpty {
            components?.queryItems = [.init(name: "app_uuid", value: projects.map { $0.id }.joined(separator: ","))]
        }

        // swiftlint:disable:next force_unwrapping
        return self.request(url: components!.url!.absoluteString)
    }
    
    func projects() -> Single<[Endpoint.Project]> {
        return self.request(url: "https://api.revenuecat.com/internal/v1/developers/me/projects")
    }
}
