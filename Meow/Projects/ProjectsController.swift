import Cocoa
import RxSwift
import AVFoundation
import SwiftUI

final class ProjectsController: DismisableController {
    private let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let child = NSHostingController(rootView: ContentView())

        self.addChild(child)
        self.view.addSubview(child.view)
        child.view.frame = self.view.bounds
    }
}

struct Project: Identifiable {
    let id: String
    let name: String
    let selected: Bool
}

class ProjectsState: ObservableObject {
    enum State {
        case loading
        case content([Project])
        case error(Swift.Error, retry: () -> Void)
    }
    
    private let bag = DisposeBag()
    private let _retry = PublishSubject<Void>()
    private let _state = PublishSubject<ProjectsState.State>()
    
    @Published var value: ProjectsState.State = .loading

    init() {
        self._retry
            .startWith(())
            .flatMapLatest { [unowned self] _ -> Observable<State> in
                return Coordinator.shared.projects()
                    .map { projects -> State in
                        let projects = projects.map { project in
                            return Project(id: project.id, name: project.name, selected: true)
                        }
                        
                        return .content(projects)
                    }
                    .catch { [unowned self] error -> Maybe<State> in
                        return .just(.error(error, retry: {
                            self._retry.onNext(())
                        }))
                    }
                    .asObservable()
                    .startWith(.loading)
            }
            .bind(to: self._state)
            .disposed(by: self.bag)
        
        self._state
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] state in
                self.value = state
            })
            .disposed(by: self.bag)
    }
    
    func clicked(project: Project) {
        print("************* SELECTED")
    }
}

struct ContentView: View {
    @StateObject var projectsState = ProjectsState()
    
    var body: some View {
        VStack {
            switch self.projectsState.value {
                case .loading:
                    Text("Loading...")
                
                case .content(let projects):
                    List {
                        ForEach(projects) { project in
                            Row(item: project) {
                                self.projectsState.clicked(project: project)
                            }
                        }
                    }
                
                case .error(let error, let retry):
                    VStack {
                        Text("Error: \(error.localizedDescription)")
                        Button("Retry") {
                            retry()
                        }
                    }
            }
        }
    }
}

struct Row: View {
    let item: Project
    let onTap: (() -> Void)?

    var body: some View {
        HStack {
            Text(self.item.name)
            Spacer()
            if self.item.selected {
                Image("checkmark")
                    .resizable()
                    .frame(width: 20)
                    .foregroundColor(Color.green)
            }
        }
        .onTapGesture {
            self.onTap?()
        }
        .frame(height: 20)
    }
}
