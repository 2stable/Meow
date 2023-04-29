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
    
    private lazy var secureStorage = SecureStorage()
    private lazy var storage = Storage(suite: "Meow")
    private lazy var session = Session()
    private lazy var api = Api(storage: self.secureStorage, session: self.session)
    
    private lazy var _state: BehaviorRelay<State> = {
        if let token = self.secureStorage.token(), !token.isExpired() {
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
                        self.stats(content: StatsController())
                    
                    case .loggedOut:
                        self.login()
                }
            })
            .disposed(by: self.bag)
    }
    
    private func stats(content: NSViewController) {
        self.setContent(isTemplate: true, controller: content, menuItems: [
            .item(Popover.MenuItem(title: "Preferences", action: { self.preferences() })),
            .item(Popover.MenuItem(title: "Logout", action: { self.logout() })),
            .item(Popover.MenuItem(title: "Quit", action: { NSApp.terminate(nil) }))
        ])
    }
    
    private func preferences() {
        self.stats(content: ProjectsController(storage: self.storage))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.popover.show()
            
            // swiftlint:disable:next force_unwrapping
            _ = self.popover.window!.rx.methodInvoked(#selector(NSWindow.close))
                .take(1)
                .observe(on: MainScheduler.asyncInstance)
                .subscribe(with: self, onNext: { `self`, _ in
                    self.stats(content: StatsController())
                })
        }
    }
    
    private func login() {
        let login = LoginController()
    
        login.token
            .subscribe(onNext: { [unowned self] token in
                self.secureStorage.set(token: token)
                
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
        self.secureStorage.purge()
        self.storage.purge()
        
        self._state.accept(.loggedOut)
    }
    
    func dismiss() {
        self.popover.dismiss()
    }
    
    func overview(projects: [Endpoint.Project] = []) -> Single<Endpoint.Overview> {
        return self.api.overview(projects: projects)
            .catchAndLogoutIfNeeded { [weak self] in
                self?.logout()
            }
    }
    
    func transactions(projects: [Endpoint.Project] = []) -> Single<Endpoint.Transactions> {
        return self.api.transactions(projects: projects)
            .catchAndLogoutIfNeeded { [weak self] in
                self?.logout()
            }
    }
    
    func projects() -> Single<[Endpoint.Project]> {
        return self.api.projects()
            .catchAndLogoutIfNeeded { [weak self] in
                self?.logout()
            }
    }
}

extension PrimitiveSequence where Trait == SingleTrait {
    func catchAndLogoutIfNeeded(_ logoutHandler: @escaping () -> Void) -> PrimitiveSequence<Trait, Element> {
        return self.catch { error in
            if case Api.Error.accessDenied = error {
                logoutHandler()
            }

            return .error(error)
        }
    }
}
