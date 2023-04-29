import Foundation
import RxSwift
import RxCocoa

internal struct Storage {
    private static let PROJECTS_KEY = "Projects"
    
    private let suite: String
    private let defaults: UserDefaults
    
    init(suite: String) {
        self.suite = suite
        
        guard let defaults = UserDefaults(suiteName: self.suite) else {
            fatalError("Something went wrong. Couldn't create UserDefaults.")
        }
        
        self.defaults = defaults
    }
    
    private func get<T>(type: T.Type, key: String) -> T? where T: Codable {
        guard let data = self.defaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode([T].self, from: data).first
    }
    
    private func set<T>(object: T, key: String) where T: Codable {
        defer {
            self.defaults.synchronize()
        }
        
        // swiftlint:disable:next force_try
        self.defaults.set(try! JSONEncoder().encode([object]), forKey: key)
    }
    
    private func delete(key: String) {
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
    
    private func observe<T>(key: String) -> Observable<T?> where T: Codable {
        return self.defaults.rx.observe(Data.self, key)
            .map { (data: Data?) in
                guard let data = data else {
                    return nil
                }
                
                return try? JSONDecoder().decode([T].self, from: data).first
            }
    }
    
    func add(project: Endpoint.Project) {
        var current = { () -> Set<Endpoint.Project> in
            guard let projects = self.get(type: Set<Endpoint.Project>.self, key: Self.PROJECTS_KEY) else {
                return []
            }
            
            return projects
        }()
        
        current.insert(project)
        
        self.set(object: current, key: Self.PROJECTS_KEY)
    }
    
    func remove(project: Endpoint.Project) {
        var current = { () -> Set<Endpoint.Project> in
            guard let projects = self.get(type: Set<Endpoint.Project>.self, key: Self.PROJECTS_KEY) else {
                return []
            }
            
            return projects
        }()
        
        current.remove(project)
        
        self.set(object: current, key: Self.PROJECTS_KEY)
    }
    
    func projects() -> Observable<Set<Endpoint.Project>> {
        return self.observe(key: Self.PROJECTS_KEY)
            .map { (projects: Set<Endpoint.Project>?) in
                guard let set = projects else {
                    return Set<Endpoint.Project>()
                }
                
                return set
            }
    }
    
    func projects() -> [Endpoint.Project] {
        return Array(self.get(type: Set<Endpoint.Project>.self, key: Self.PROJECTS_KEY) ?? .init())
    }
}
