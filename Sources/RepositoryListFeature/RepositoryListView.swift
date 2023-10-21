import CasePaths
import ComposableArchitecture
import SwiftUI
import IdentifiedCollections
import RepositoryDetailFeature
import GitHubAPIClient
import Entity

public struct RepositoryList: Reducer {
    public struct State: Equatable {
        var repositoryRows: IdentifiedArrayOf<RepositoryRow.State> = []
        var isLoading: Bool = false
        @BindingState var query: String = ""
        @PresentationState var destination: Destination.State?

        public init() {}
    }

    @Dependency(\.gitHubAPIClient) var gitHubApiClient
    @Dependency(\.mainQueue) var mainQueue

    public init() {}

    public enum Action: Equatable, BindableAction {
        case onAppear
        case searchRepositoriesResponse(TaskResult<[Repository]>)
        case repositoryRow(
            id: RepositoryRow.State.ID,
            action: RepositoryRow.Action
        )
        case queryChangeDebounced
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)

        public enum Alert: Equatable {

        }
    }

    private enum CancelID: Hashable {
        case response
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return searchRepositories(by: "composable")
            case .searchRepositoriesResponse(let result):
                state.isLoading = false
                switch result {
                case .success(let repositories):
                    state.repositoryRows = .init(uniqueElements:
                                                    repositories.map {
                        RepositoryRow.State(repository: $0)
                    }
                    )
                    return .none
                case .failure:
                    state.destination = .alert(.networkError)
                    return .none
                }
            case .queryChangeDebounced:
                if state.query.isEmpty {
                    return .none
                }
                state.isLoading = true
                return searchRepositories(by: state.query)
            case .binding(\.$query):
                return .run { send in
                    await send(.queryChangeDebounced)
                }
                .debounce(id: CancelID.response,
                          for: .seconds(0.3), scheduler: mainQueue)
            case .binding(_):
                return .none
            case .destination:
                return .none
            case .repositoryRow(let id, .delegate(.rowTapped)):
                guard let repository = state.repositoryRows[id: id]?.repository else {
                    return .none
                }
                state.destination = .repositoryDetail(RepositoryDetail.State(repository: repository))
                return .none
            case .repositoryRow:
                return .none
            }
        }
        .forEach(\.repositoryRows, action: /Action.repositoryRow(id:action:)) {
            RepositoryRow()
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination()
        }
    }

    func searchRepositories(by query: String) -> Effect<Action> {
        Effect<Action>.run { send in
            await send(
                Action.searchRepositoriesResponse(
                    TaskResult {
                        try await gitHubApiClient.searchRepositories(query)
                    }
                )
            )
        }
    }

}

extension AlertState where Action == RepositoryList.Destination.Action.Alert {
    static let networkError = Self {
        TextState("Network Error")
    } message: {
        TextState("Failed to fetch data.")
    }
}

public struct RepositoryListView: View {
    let store: StoreOf<RepositoryList>

    public init(store: StoreOf<RepositoryList>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            WithViewStore(store, observe: { $0 }) { viewStore in
                Group {
                    if viewStore.isLoading {
                        ProgressView()
                    } else {
                        List {
                            ForEachStore(
                                store.scope(
                                    state: { $0.repositoryRows },
                                    action: { .repositoryRow(id: $0, action: $1)
                                    }
                                ),
                                content: RepositoryRowView.init(store:)
                            )
                        }
                    }
                }
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .navigationTitle("Repositories")
                .searchable(text: viewStore.$query, placement: .navigationBarDrawer, prompt: "Input Query")
                .alert(store: store.scope(
                    state: { $0.$destination },
                    action: { .destination($0) }
                ), state: /RepositoryList.Destination.State.alert, action: RepositoryList.Destination.Action.alert)
                .navigationDestination(
                    store: store.scope(state: { $0.$destination }, action: { .destination($0) }),
                    state: /RepositoryList.Destination.State.repositoryDetail,
                    action: RepositoryList.Destination.Action.repositoryDetail,
                    destination: RepositoryDetailView.init(store:)
                )
            }
        }
    }
}

#Preview("API Succeeded") {
    RepositoryListView(
        store: StoreOf<RepositoryList>(
            initialState:
                RepositoryList.State(),
            reducer: { withDependencies {
                $0.gitHubAPIClient.searchRepositories = { _ in
                    try await Task.sleep(nanoseconds: 100_000_000 * 3)
                    return (1...20).map({ Repository.mock(id: $0) })
                }
            } operation: {
                RepositoryList()
            }
            }
        )
    )
}

#Preview("API Failed") {
    enum PreviewError: Error {
        case fetchFailed
    }
    return RepositoryListView(
        store: .init(
            initialState: RepositoryList.State()
        ) {
            RepositoryList()
        } withDependencies: {
            $0.gitHubAPIClient.searchRepositories = { _ in
                throw PreviewError.fetchFailed
            }
        }
    )
}

extension RepositoryList {
    public struct Destination: Reducer {
        public enum State: Equatable {
            case alert(AlertState<Action.Alert>)
            case repositoryDetail(RepositoryDetail.State)
        }

        public enum Action: Equatable {
            case alert(Alert)
            case repositoryDetail(RepositoryDetail.Action)
            public enum Alert: Equatable { }
        }

        public var body: some ReducerOf<Self> {
            Scope(state: /State.repositoryDetail, action: /Action.repositoryDetail) {
                RepositoryDetail()
            }
        }
    }
}
