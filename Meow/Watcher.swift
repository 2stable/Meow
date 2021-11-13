import Foundation
import RxSwift

final class Watcher {
    private static let INTERVAL = 30
    
    private var bag: Disposable?
    private var op: Cancelable?
    
    private var scheduler = SerialDispatchQueueScheduler(qos: .userInitiated)
    
    private let _response = PublishSubject<Endpoint.Response>()
    var response: Observable<Endpoint.Response> {
        return self._response
    }
    
    final func start() {
        self.bag = Observable<Int>.interval(.seconds(Self.INTERVAL), scheduler: self.scheduler)
            .startWith(0)
            .observe(on: self.scheduler)
            .subscribe(onNext: { [weak self] _ in
                self?.process()
            })
    }
    
    final func stop() {
        self.bag?.dispose()
    }
    
    private func process() {
        guard self.op == nil || self.op?.isDisposed == true else {
            return
        }
        
        self.op = Disposables.create {}
        
        _ = Coordinator.shared.request()
            .subscribe(onSuccess: { [weak self] response in
                self?._response.onNext(response)
            }, onDisposed: { [weak self] in
                self?.op?.dispose()
            })
    }
}
