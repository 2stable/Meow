import Foundation
import WebKit
import RxSwift
import RxCocoa

public final class WebView: NSView {
    public struct Cookie: Hashable {
        let name: String
        let value: String
    }
    
    public enum Action {
        case start(URLRequest, (WKNavigationActionPolicy) -> Void)
        case finish(Swift.Error?)
    }
    
    private var bag = DisposeBag()
    private var webView: WKWebView!
    private var navigation: NavigationDelegate!
    
    private let _action = PublishSubject<Action>()
    public var action: Observable<Action> {
        return self._action
    }
    
    private let _webViewObserver = WebViewObserver()
    
    public var cookies: Infallible<Set<WebView.Cookie>> {
        return self._webViewObserver._cookies
            .distinctUntilChanged()
            .asInfallible { _ in
                fatalError("Invalid State")
            }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override var canBecomeKeyView: Bool {
        return true
    }
    
    deinit {
        WKWebsiteDataStore.default().removeData(
            ofTypes: [
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeOfflineWebApplicationCache,
                WKWebsiteDataTypeMemoryCache,
                WKWebsiteDataTypeLocalStorage,
                WKWebsiteDataTypeCookies,
                WKWebsiteDataTypeSessionStorage,
                WKWebsiteDataTypeIndexedDBDatabases,
                WKWebsiteDataTypeWebSQLDatabases,
                WKWebsiteDataTypeFetchCache,
                WKWebsiteDataTypeServiceWorkerRegistrations
            ],
            modifiedSince: Date(timeIntervalSince1970: 0),
            completionHandler: {}
        )
    }
    
    public func load(request: URLRequest, scroll: Bool = true, userAgent: String = "Mozilla/5.0") {
        let controller = WKUserContentController()
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.add(self._webViewObserver)
        
        configuration.websiteDataStore = dataStore
        
        self.webView?.removeFromSuperview()
        
        let wv = WKWebView(frame: self.bounds, configuration: configuration)
        wv.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(wv)
        
        wv.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        wv.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        wv.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        wv.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        wv.allowsBackForwardNavigationGestures = true
        wv.customUserAgent = userAgent
        
        self.navigation = NavigationDelegate()
        wv.navigationDelegate = self.navigation
        
        self.webView = wv
        
        self.navigation.action
            .flatMap { action -> Observable<Action> in
                switch action {
                    case .didFinish:
                        return .just(.finish(nil))

                    case .didFail(let error):
                        return .just(.finish(error))

                    case .decidePolicy(let navigationAction, let decisionHandler):
                        switch navigationAction.navigationType {
                            case .linkActivated:
                                return .just(.start(navigationAction.request, decisionHandler))

                            default:
                                decisionHandler(.allow)
                            
                                return .empty()
                        }
                }
            }
            .bind(to: self._action)
            .disposed(by: self.bag)

        wv.load(request)
    }
    
    private final class NavigationDelegate: NSObject, WKNavigationDelegate {
        enum NavigationAction {
            case didFinish
            case didFail(Swift.Error)
            case decidePolicy(WKNavigationAction, (WKNavigationActionPolicy) -> Void)
        }
        
        let action = PublishSubject<NavigationAction>()
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            return self.action.onNext(.decidePolicy(navigationAction, decisionHandler))
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            return self.action.onNext(.didFinish)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            return self.action.onNext(.didFail(error))
        }
    }
}

private class WebViewObserver: NSObject, WKHTTPCookieStoreObserver {
    fileprivate let _cookies = PublishSubject<Set<WebView.Cookie>>()
    
     func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
         DispatchQueue.main.async {
            cookieStore.getAllCookies { cookies in
                self._cookies.onNext(Set(cookies.map { WebView.Cookie(name: $0.name, value: $0.value) }))
            }
         }
     }
}
