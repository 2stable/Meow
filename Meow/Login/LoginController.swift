import Cocoa
import RxSwift

final class LoginController: DismisableController {
    private static let RC_AUTH_TOKEN = "rc_auth_token"
    private static let RC_AUTH_TOKEN_EXPIRATION = "rc_auth_token_expiration"
    
    let bag = DisposeBag()
    
    @IBOutlet private weak var _webView: WebView!
    
    private let _token = PublishSubject<Token>()
    var token: Observable<Token> {
        return self._token
    }
    
    private lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self._webView.cookies
            .compactMap { [unowned self] in
                guard
                    let token = $0.first(where: { $0.name == Self.RC_AUTH_TOKEN }),
                    let _expiration = $0.first(where: { $0.name == Self.RC_AUTH_TOKEN_EXPIRATION }),
                    let expiration = self.formatter.date(from: _expiration.value)
                else {
                    return nil
                }

                return Token(value: token.value, expiration: expiration)
            }
            .take(1)
            .bind(to: self._token)
            .disposed(by: self.bag)

        // swiftlint:disable:next force_unwrapping
        self._webView.load(request: .init(url: .init(string: "https://app.revenuecat.com/login")!))
    }
    
    deinit {
        print(type(of: self), #function)
    }
}
