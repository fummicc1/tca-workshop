import ComposableArchitecture
import Entity
import XCTest


@testable import RepositoryListFeature


@MainActor
final class RepositoryListFeatureTests: XCTestCase {
  func testOnAppear_SearchSucceeded() async {
      let response: [Repository] = (1...10).map {
          .mock(id: $0)
      }
      let testStore = TestStore(
        initialState: RepositoryList.State(),
        reducer: {
            withDependencies {
                $0.gitHubAPIClient.searchRepositories = { _ in
                    response
                }
            } operation: {
                RepositoryList()
            }

        })
      await testStore.send(.onAppear) {
          $0.isLoading = true
      }
      await testStore.receive(/RepositoryList.Action.searchRepositoriesResponse(.success(response))) {
          $0.isLoading = false
          $0.repositoryRows = IdentifiedArrayOf<RepositoryRow.State>.init(uniqueElements: response.map({
              RepositoryRow.State(repository: $0)
          }))
      }
  }

    func testQuerySearch() async {
        let response: [Repository] = (1...10).map {
            .mock(id: $0)
        }
        let queue = DispatchQueue.test
        let testStore = TestStore(
          initialState: RepositoryList.State(),
          reducer: {
              withDependencies {
                  $0.gitHubAPIClient.searchRepositories = { _ in
                      response
                  }
                  $0.mainQueue = .init(queue)
              } operation: {
                  RepositoryList()
              }
          })
        await testStore.send(.binding(.set(\.$query, "test"))) {
            $0.query = "test"
        }
        await queue.advance(by: .seconds(0.3))
        await testStore.receive(.queryChangeDebounced) {
            $0.isLoading = true
        }
        await testStore.receive(.searchRepositoriesResponse(.success(response))) {
            $0.isLoading = false
            $0.repositoryRows = IdentifiedArray(uniqueElements: response.map({
                RepositoryRow.State(repository: $0)
            }))
        }
    }
}
