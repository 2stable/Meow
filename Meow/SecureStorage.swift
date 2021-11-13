import Foundation
import KeychainAccess

struct Token {
    let value: String
    let expiration: Date
    
    func isExpired() -> Bool {
        return self.expiration < Date()
    }
}

struct SecureStorage {
    private static let KEY_TOKEN_VALUE = "token"
    private static let KEY_TOKEN_EXPIRATION = "expiration"
    
    // swiftlint:disable:next force_unwrapping
    let keychain = Keychain(service: Bundle.main.bundleIdentifier!).accessibility(.afterFirstUnlock)
    
    func set(token: Token) {
        self.keychain[string: Self.KEY_TOKEN_VALUE] = token.value
        self.keychain[string: Self.KEY_TOKEN_EXPIRATION] = String(token.expiration.timeIntervalSince1970)
    }
    
    func token() -> Token? {
        if let token = self.keychain[Self.KEY_TOKEN_VALUE], let _expiration = self.keychain[Self.KEY_TOKEN_EXPIRATION], let _timeInterval = TimeInterval(_expiration) {
            return .init(value: token, expiration: Date(timeIntervalSince1970: _timeInterval))
        }
        
        return nil
    }
    
    func purge() {
        // swiftlint:disable:next force_try
        try! self.keychain.removeAll()
    }
}
