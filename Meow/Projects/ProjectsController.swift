import Cocoa
import RxSwift
import AVFoundation
import SwiftUI

final class ProjectsController: DismisableController {
    private let bag = DisposeBag()
    
    private let storage: Storage
    
    init(storage: Storage) {
        self.storage = storage
        
        super.init(nibName: "ProjectsController", bundle: .main)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let child = NSHostingController(rootView: ContentView(projectsState: .init(storage: self.storage)))

        self.addChild(child)
        self.view.addSubview(child.view)
        child.view.frame = self.view.bounds
    }
}

struct Project: Identifiable {
    let endpointProject: Endpoint.Project
    let selected: Bool
    
    var id: String {
        return self.endpointProject.id
    }
}

class ProjectsState: ObservableObject {
    enum State {
        case loading
        case content([Project])
        case error(Swift.Error, retry: () -> Void)
    }
    
    private let bag = DisposeBag()
    private let _retry = PublishSubject<Void>()
    private let storage: Storage
    
    @Published var value: ProjectsState.State = .loading

    init(storage: Storage) {
        self.storage = storage
        
        self._retry
            .startWith(())
            .flatMapLatest { [unowned self] _ -> Observable<State> in
                Observable.combineLatest(Coordinator.shared.projects().asObservable(), storage.projects())
                    .flatMapLatest({ projects, stored -> Observable<State> in
                        let projects = projects.map { project in
                            return Project(endpointProject: project, selected: stored.contains(where: { $0.id == project.id }))
                        }
                            
                        return .just(.content(projects))
                    })
                    .catch { [unowned self] error -> Observable<State> in
                        return .just(.error(error, retry: { [unowned self] in
                            self._retry.onNext(())
                        }))
                    }
                    .startWith(.loading)
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [unowned self] state in
                self.value = state
            })
            .disposed(by: self.bag)
    }
    
    func clicked(project: Project) {
        if project.selected {
            self.storage.remove(project: project.endpointProject)
        } else {
            self.storage.add(project: project.endpointProject)
        }
    }
}

struct ContentView: View {
    @ObservedObject var projectsState: ProjectsState
    
    var body: some View {
        VStack {
            switch self.projectsState.value {
                case .loading:
                    Text("Loading...")
                
                case .content(let projects):
                    VStack {
                        Text("Select projects:")
                            .padding(.top)
                        ScrollView {
                            LazyVStack(alignment: .leading) {
                                ForEach(projects) { project in
                                    Row(item: project)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            self.projectsState.clicked(project: project)
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                    .padding(5)
                
                case .error(let error, let retry):
                    VStack(spacing: 20) {
                        Text("Error: \(error.localizedDescription)")
                            .multilineTextAlignment(.center)
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

    var body: some View {
        HStack {
            Text(self.item.endpointProject.name)
                .foregroundColor(self.item.selected ? .green : .gray)
            Spacer()
            Image(systemName: "checkmark" )
                .foregroundColor(self.item.selected ? .green : .gray)
        }
        .frame(height: 20)
    }
}
