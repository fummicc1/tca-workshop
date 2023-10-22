import ComposableArchitecture
import Entity
import UserDefaultsClient
import XCTest


@testable import RepositoryDetailFeature


@MainActor
final class RepositoryDetailFeatureTests: XCTestCase {
	var favorites: [Repository.ID] = []
	var userDefault: MockUserDefaults!

	override func setUp() {
		super.setUp()
		favorites = []
		userDefault = MockUserDefaults { [self] key in
			XCTAssertEqual(key, .favoriteRepositories)
			return favorites
		} onSet: { [self] value, key in
			XCTAssertEqual(key, .favoriteRepositories)
			XCTAssertTrue(value is [Repository.ID])
			favorites = value as! [Repository.ID]
		}
	}

	func test_addFavorite() async {
		let repository: Repository = .mock(id: 10)
		let testStore = TestStore(
			initialState: RepositoryDetail.State(repository: repository),
			reducer: {
				withDependencies {
					$0.userDefaults = .init(storage: userDefault)
				} operation: {
					RepositoryDetail()
				}
			})
		testStore.assert { state in
			state.favorite = .inactive
		}
		await testStore.send(.toggleFavorite)
		await testStore.receive(.didFavorite(.success(favorites))) {
			$0.favorite = .active
		}
	}

	func test_removeFavorite() async {
		let repository: Repository = .mock(id: 10)
		favorites.append(repository.id)

		let testStore = TestStore(
			initialState: RepositoryDetail.State(repository: repository, favorite: .active),
			reducer: {
				withDependencies {
					$0.userDefaults = .init(storage: userDefault)
				} operation: {
					RepositoryDetail()
				}
			})
		testStore.assert { state in
			state.favorite = .active
		}
		await testStore.send(.toggleFavorite)
		await testStore.receive(.didFavorite(.success(favorites))) {
			$0.favorite = .inactive
		}
	}
}
