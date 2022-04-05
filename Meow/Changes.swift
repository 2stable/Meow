import Foundation
import RxSwift

final class Changes {
    struct Value {
        let current: Endpoint.Response
        let play: UInt
    }
    
    private let bag = DisposeBag()
    private var previous: Endpoint.Response?
    
    private let watcher = Watcher()
    
    private let _changes = ReplaySubject<Value>.create(bufferSize: 1)
    public var changes: Observable<Value> {
        return self._changes
    }
    
    init() {
        self.watcher.response
            .map { [unowned self] current -> Value in
                let play = { () -> UInt in
                    guard let previous = self.previous else {
                        return 0
                    }
                     
                    return UInt(current.transactions.subtracting(previous.transactions).count)
                }()

                self.previous = current
                
                return Value(
                    current: current,
                    play: play
                )
            }
            .bind(to: self._changes)
            .disposed(by: self.bag)

        self.watcher.start()
    }
}
