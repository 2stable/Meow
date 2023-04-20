import AppKit
import Popover
import RxSwift
import RxRelay

private final class Config: DefaultConfiguration {
    public override var arrowHeight: CGFloat {
        return 0
    }

    public override var arrowWidth: CGFloat {
        return 0
    }
}

final class Coordinator {
    static let shared = Coordinator()
    private let bag = DisposeBag()
    
    enum State {
        case loggedIn(Token)
        case loggedOut
    }
    
    private let storage = SecureStorage()
    private lazy var session = Session()
    
    private lazy var _state: BehaviorRelay<State> = {
        if let token = self.storage.token(), !token.isExpired() {
            return BehaviorRelay<State>(value: .loggedIn(token))
        }
        
        return BehaviorRelay<State>(value: .loggedOut)
    }()
    
    private let popover: Popover
    
    private init() {
        self.popover = Popover(with: Config())
        
        self._state
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [unowned self] state in
                switch state {
                    case .loggedIn:
                        self.stats()
                    
                    case .loggedOut:
                        self.login()
                }
            })
            .disposed(by: self.bag)
    }
    
    private func stats() {
        self.setContent(isTemplate: true, controller: StatsController(), menuItems: [
            .item(Popover.MenuItem(title: "Logout", action: { self.logout() })),
            .item(Popover.MenuItem(title: "Quit", action: { NSApp.terminate(nil) }))
        ])
    }
    
    private func login() {
        let login = LoginController()
    
        login.token
            .subscribe(onNext: { [unowned self] token in
                self.storage.set(token: token)
                
                self._state.accept(.loggedIn(token))
            })
            .disposed(by: login.bag)
    
        self.setContent(isTemplate: false, controller: login, menuItems: [
            .item(Popover.MenuItem(title: "Quit", action: { NSApp.terminate(nil) }))
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.popover.show()
        }
    }
    
    private func setContent(isTemplate: Bool, controller: NSViewController, menuItems: [Popover.MenuItemType]) {
        self.dismiss()
        
        // swiftlint:disable:next force_unwrapping
        self.popover.prepare(with: NSImage(named: "Icon")!, contentViewController: controller, menuItems: menuItems)
        // This is a workaround for Popover, as for now it don't support isTemplate = false.
        // But I am too lazy to do a PR, maybe sometime, sry.
        (self.popover.value(forKey: "item") as? NSStatusItem)?.button?.image?.isTemplate = isTemplate
    }
    
    private func logout() {
        self.storage.purge()
        
        self._state.accept(.loggedOut)
    }
    
    func overview() -> Maybe<Endpoint.Overview> {
        return self.request(url: "https://api.revenuecat.com/v1/developers/me/overview")
    }
    
    func transactions() -> Maybe<Endpoint.Transactions> {
        return self.request(url: "https://api.revenuecat.com/v1/developers/me/transactions")
    }
    
    func projects() -> Maybe<[Endpoint.Project]> {
        return self.request(url: "https://api.revenuecat.com/internal/v1/developers/me/projects")
    }
    
    private func request<T: Codable>(url: String) -> Maybe<T> {
        guard let token = self.storage.token() else {
            return .empty()
        }
    
        // If someone at RevenueCat has a better idea or there is another API that we can use
        // Please feel free to contact us, or open a PR
        guard !token.isExpired(), let url = URL(string: url) else {
            self.logout()
            
            return .empty()
        }
        
        return self.session.json(request: .get(url: url, headers: [
            // swiftlint:disable:next force_https
            "X-Requested-With": "XMLHttpRequest",
            "Cookie": "rc_auth_token=\(token.value)"
        ]))
        .asMaybe()
        .catch { [weak self] error in
            if case Session.Error.code(_, let response) = error {
                let error = try JSONDecoder().decode(Endpoint.Error.self, from: response)
                
                if error.code == 7_224 {
                    self?.logout()
                }
            }
            
            return .empty()
        }
    }
    
    func dismiss() {
        self.popover.dismiss()
    }
}
