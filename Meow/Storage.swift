import Foundation
import RxSwift
import RxCocoa

internal struct Storage {
    private let suite: String
    private let defaults: UserDefaults
    
    init(suite: String) {
        self.suite = suite
        
        guard let defaults = UserDefaults(suiteName: self.suite) else {
            fatalError("Something went wrong. Couldn't create UserDefaults.")
        }
        
        self.defaults = defaults
    }
    
    func get<T>(type: T.Type, key: String) -> T? where T: Codable {
        guard let data = self.defaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode([T].self, from: data).first
    }
    
    func set<T>(object: T, key: String) where T: Codable {
        defer {
            self.defaults.synchronize()
        }
        
        // swiftlint:disable:next force_try
        self.defaults.set(try! JSONEncoder().encode([object]), forKey: key)
    }
    
    func delete(key: String) {
        defer {
            self.defaults.synchronize()
        }
        
        self.defaults.removeObject(forKey: key)
    }
    
    func purge() {
        defer {
            self.defaults.synchronize()
        }
        
        self.defaults.removePersistentDomain(forName: self.suite)
    }
    
    func observe<T>(key: String) -> Observable<T?> where T: Codable {
        return self.defaults.rx.observe(Data.self, key)
            .map { (data: Data?) in
                guard let data = data else {
                    return nil
                }
                
                return try? JSONDecoder().decode([T].self, from: data).first
            }
    }
}
