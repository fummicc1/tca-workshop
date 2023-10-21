import CasePaths
import ComposableArchitecture
import SwiftUI
import IdentifiedCollections
import GitHubAPIClient
import Entity

public struct RepositoryList: Reducer {
    public struct State: Equatable {
        var repositoryRows: IdentifiedArrayOf<RepositoryRow.State> = []
        var isLoading: Bool = false
        @BindingState var query: String = ""

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
                    return .none
                }
            case let .repositoryRow(_, action):
                switch action {
                case .rowTapped:
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
            }
        }
        .forEach(\.repositoryRows, action: /Action.repositoryRow(id:action:)) {
            RepositoryRow()
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
            }
        }

    }
}

#Preview {
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
