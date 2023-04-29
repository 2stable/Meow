import Cocoa
import RxSwift
import AVFoundation

final class StatsController: DismisableController {
    private let bag = DisposeBag()
    
    // swiftlint:disable:next force_unwrapping
    private lazy var sound = NSSound(named: "meow.wav")!
    private let changes: Changes
    
    @IBOutlet private weak var _activeSubscribers: NSTextField!
    
    init(storage: Storage) {
        self.changes = Changes(storage: storage)
        
        super.init(nibName: "StatsController", bundle: .main)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setUpChanges()
    }
    
    private func setUpChanges() {
        self.changes.changes
            .observe(on: MainScheduler.instance)
            .subscribe(with: self, onNext: { _self, value in
                _self._activeSubscribers.stringValue = String(value.current.overview.activeSubscriptions())
                
                _self.play(value.play)
            })
            .disposed(by: self.bag)
    }
    
    private func play(_ n: UInt) {
        let sounds = (0..<n).map { _ in
            return Observable<Void>.deferred { [unowned self] in
                self.sound.play()
                
                return .just(())
            }
            .delay(.seconds(Int(self.sound.duration.rounded(.up))), scheduler: MainScheduler.instance)
        }
        
        _ = Observable.concat(sounds)
            .subscribe()
    }
    
    deinit {
        print(type(of: self), #function)
    }
}
