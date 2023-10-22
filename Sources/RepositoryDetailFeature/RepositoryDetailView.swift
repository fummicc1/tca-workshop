import ComposableArchitecture
import Utils
import UserDefaultsClient
import Entity
import GitHubAPIClient
import SwiftUI
import UserDefaultsClient
import WebKit

public enum FavoriteState {
	case active
	case inactive

	var iconName: String {
		if self == .active { "heart.fill" } else { "heart" }
	}
}

public struct RepositoryDetail: Reducer {
	public struct State: Equatable {
		let repository: Repository

		@BindingState var isWebViewLoading = true
		var favorite: FavoriteState

		public init(repository: Repository, favorite: FavoriteState = .inactive) {
			self.repository = repository
			self.favorite = favorite
		}
	}

	@Dependency(\.userDefaults) var userDefaults

	public enum Action: Equatable, BindableAction {
		case binding(BindingAction<State>)
		case onAppear
		case toggleFavorite
		case didFavorite(TaskResult<[Repository.ID]>)
	}

	public init() {}

	public var body: some ReducerOf<Self> {
		BindingReducer()
		Reduce { state, action in
			switch action {
			case .onAppear:
				return .run { send in
					await send(.didFavorite(TaskResult {
						try await fetchFavorites()
					}))
				}
			case .binding:
				return .none
			case .toggleFavorite:
				return .run { [state] send in
					await send(.didFavorite(TaskResult {
						if state.favorite == .active {
							try await userDefaults.removeFavorite(
								id: state.repository.id
							)
						} else {
							try await userDefaults.addFavorite(
								id: state.repository.id
							)
						}
						return try await fetchFavorites()
					 }
				 ))
				}
			case .didFavorite(let result):
				switch result {
				case .success(let ids):
					if ids.contains(state.repository.id) {
						state.favorite = .active
					} else {
						state.favorite = .inactive
					}
					return .none
				case .failure:
					return .none
				}
			}
		}
	}

	private func fetchFavorites() async throws -> [Repository.ID] {
		try await userDefaults.getFavorites().map { $0 }
	}
}

public struct RepositoryDetailView: View {
	let store: StoreOf<RepositoryDetail>

	public init(store: StoreOf<RepositoryDetail>) {
		self.store = store
	}

	public var body: some View {
		WithViewStore(store, observe: { $0 }) { viewStore in
			SimpleWebView(
				url: viewStore.repository.htmlUrl,
				isLoading: viewStore.$isWebViewLoading
			)
			.overlay(alignment: .center) {
				if viewStore.isWebViewLoading {
					ProgressView()
				}
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar(content: {
				Button {
					viewStore.send(.toggleFavorite)
				} label: {
					Image(systemName: viewStore.favorite.iconName)
				}
			})
			.onAppear {
				viewStore.send(.onAppear)
			}
		}
	}
}

struct SimpleWebView: UIViewRepresentable {
	let url: URL
	@Binding var isLoading: Bool

	private let webView = WKWebView()

	func makeUIView(context: Context) -> some UIView {
		webView.load(.init(url: url))
		webView.navigationDelegate = context.coordinator
		return webView
	}

	func updateUIView(_ uiView: UIViewType, context: Context) {}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, WKNavigationDelegate {
		let parent: SimpleWebView

		init(_ parent: SimpleWebView) {
			self.parent = parent
		}

		func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
			parent.isLoading = true
		}

		func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
			parent.isLoading = false
		}
	}
}

#Preview {
	RepositoryDetailView(
		store: .init(
			initialState: RepositoryDetail.State(
				repository: .mock(id: 1)
			)
		) {
			RepositoryDetail()
		}
	)
}
