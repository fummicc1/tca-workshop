import ComposableArchitecture
import Entity
import XCTest

@testable import RepositoryListFeature

@MainActor
final class RepositoryListFeatureTests: XCTestCase {
  func testOnAppear_SeachSucceeded() async {
    let response: [Repository] = (1...10).map {
      .mock(id: $0)
    }

    let store = TestStore(
      initialState: RepositoryList.State()
    ) {
      RepositoryList()
    } withDependencies: {
      $0.gitHubAPIClient.searchRepositories = { _ in response }
    }
    
    await store.send(.onAppear) {
      $0.isLoading = true
    }
    await store.receive(.searchRepositoriesResponse(.success(response))) {
      $0.repositoryRows = .init(
        uniqueElements: response.map {
          .init(repository: $0)
        }
      )
      $0.isLoading = false
    }
  }
  
  func testOnAppear_SearchFailed() async {
    let store = TestStore(
      initialState: RepositoryList.State()
    ) {
      RepositoryList()
    } withDependencies: {
      $0.gitHubAPIClient.searchRepositories = { _ in
        throw TestError.search
      }
    }
    
    await store.send(.onAppear) {
      $0.isLoading = true
    }
    await store.receive(.searchRepositoriesResponse(.failure(TestError.search))) {
      $0.alert = .networkError
      $0.isLoading = false
    }
  }

  func testQueryChanged() async {
    let response: [Repository] = (1...10).map {
      .mock(id: $0)
    }
    let testClock = TestClock()

    let store = TestStore(
      initialState: RepositoryList.State()
    ) {
      RepositoryList()
    } withDependencies: {
      $0.continuousClock = testClock
      $0.gitHubAPIClient.searchRepositories = { _ in response }
    }

    await store.send(.binding(.set(\.$query, "test"))) {
      $0.query = "test"
    }
    await testClock.advance(by: .seconds(0.3))
    await store.receive(.queryChangeDebounced) {
      $0.isLoading = true
    }
    await store.receive(.searchRepositoriesResponse(.success(response))) {
      $0.repositoryRows = .init(
        uniqueElements: response.map {
          .init(repository: $0)
        }
      )
      $0.isLoading = false
    }
  }

  func testRepositoryRowTapped() async {
    var state = RepositoryList.State()
    state.repositoryRows.append(
      .init(
        repository: .mock(id: 1)
      )
    )
    let store = TestStore(
      initialState: state
    ) {
      RepositoryList()
    }

    await store.send(.repositoryRows(id: 1, action: .delegate(.openRepositoryDetail(.mock(id: 1))))) {
      $0.path = .init(
        [
          .repositoryDetail(.init(repository: .mock(id: 1)))
        ]
      )
    }
  }
}

private enum TestError: Error {
  case search
}
