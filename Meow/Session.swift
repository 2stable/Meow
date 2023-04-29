import Foundation
import RxSwift
import RxCocoa

final class Session {
    enum Error: Swift.Error {
        case code(Int, Data)
    }
    
    enum Request {
        case get(url: URL, headers: [String: String] = [:])
    }
    
    private struct Response: Codable {
        let encoding: String.Encoding
        let data: Data
    }
    
    #if DEBUG
    private lazy var _config: URLSessionConfiguration = {
        let config = URLSessionConfiguration.default
        
//        config.connectionProxyDictionary = [AnyHashable: Any]()
//        config.connectionProxyDictionary?[kCFNetworkProxiesHTTPEnable as String] = 1
//        config.connectionProxyDictionary?[kCFNetworkProxiesHTTPProxy as String] = "127.0.0.1"
//        config.connectionProxyDictionary?[kCFNetworkProxiesHTTPPort as String] = 8_888
//        config.connectionProxyDictionary?[kCFStreamPropertyHTTPSProxyHost as String] = "127.0.0.1"
//        config.connectionProxyDictionary?[kCFStreamPropertyHTTPSProxyPort as String] = 8_888

        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        URLSession.rx.shouldLogRequest = { _ in
           return false
        }
        
        return config
    }()
    #else
    private lazy var _config: URLSessionConfiguration = {
        let config = URLSessionConfiguration.default
        
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        return config
    }()
    #endif
    
    private lazy var _session: URLSession = {
        #if DEBUG
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 10
        
        let session = URLSession(configuration: self._config, delegate: Delegate(), delegateQueue: queue)
        #else
        let session = URLSession(configuration: self._config)
        #endif
        
        return session
    }()
    
    init() {}
    
    private func data(request: Session.Request) -> Single<Response> {
        let make = { (url: URL, headers: [String: String]) -> URLRequest in
            var request = URLRequest(url: url)
            
            headers.forEach {
                guard !$1.isEmpty else {
                    return
                }
                
                request.addValue($1, forHTTPHeaderField: $0)
            }
            
            return request
        }
        
        switch request {
            case .get(let url, let headers):
                return self.data(request: make(url, headers))
        }
    }
    
    private func data(request: URLRequest) -> Single<Response> {
        return self._session.rx.response(request: request)
            .map {
                if (200..<300).contains($0.response.statusCode) {
                    return Response(encoding: Self.encoding(from: $0.response), data: $0.data)
                }
                
                throw Error.code($0.response.statusCode, $0.data)
            }
            .asSingle()
    }
    
    private static func encoding(from response: URLResponse) -> String.Encoding {
        if let _encoding = response.textEncodingName {
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(_encoding as CFString)))
        }
            
        return .utf8
    }
    
    func data(request: Session.Request) -> Single<Data> {
        return self.data(request: request).map { $0.data }
    }
    
    func json<T>(request: Session.Request) -> Single<T> where T: Decodable {
        return self.data(request: request)
            .map { try JSONDecoder().decode(T.self, from: $0) }
    }
    
    func plist<T>(request: Session.Request) -> Single<T> where T: Decodable {
        return self.data(request: request)
            .map { try PropertyListDecoder().decode(T.self, from: $0) }
    }
    
    func string(request: Session.Request) -> Single<String> {
        return self.data(request: request).map { (response: Response) in
            // swiftlint:disable:next force_unwrapping
            return String(data: response.data, encoding: response.encoding)!
        }
    }
}

private final class Delegate: NSObject, URLSessionDelegate {
    // WARNING: For now we ignore SSL and trust to all.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // swiftlint:disable:next force_unwrapping
        return completionHandler(.useCredential, .init(trust: challenge.protectionSpace.serverTrust!))
    }
}

extension URLRequest {
    func key() -> String {
        let headers = (self.allHTTPHeaderFields ?? [:]).sorted(by: { $0.key > $1.key }).reduce("", { (prev, header) in
            return prev + header.key + header.value
        })
        
        return (self.url?.absoluteString ?? "") + headers
    }
}

extension String.Encoding: Codable {}
