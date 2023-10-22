import Entity
import Foundation
import Dependencies
import XCTestDynamicOverlay
import Utils

public protocol UserDefaultsType {
	func object(forKey key: UserDefaultsClient.Key) -> Any?
	func object(forKey key: String) -> Any?

	func setValue(_ value: Any?, forKey key: String)
	func setValue(_ value: Any?, forKey key: UserDefaultsClient.Key)
}

public struct UserDefaultsClient {

	var storage: UserDefaultsType

	public func getFavorites() async throws -> Set<Repository.ID> {
		let favorites = storage.object(forKey: .favoriteRepositories)
		guard let favorites = favorites as? Array<Repository.ID> else {
			throw CastError(value: favorites, to: [Repository.ID].self)
		}
		return Set(favorites)
	}

	public func addFavorite(id: Repository.ID) async throws {
		var favorites = Set(try await getFavorites())
		favorites.insert(id)
		storage.setValue(Array(favorites), forKey: .favoriteRepositories)
	}

	public func removeFavorite(id: Repository.ID) async throws {
		var favorites = Set(try await getFavorites())
		favorites.remove(id)
		storage.setValue(Array(favorites), forKey: .favoriteRepositories)
	}

	public init(storage: UserDefaultsType) {
		self.storage = storage
	}
}

extension UserDefaultsClient {
	public enum Key: String {
		case favoriteRepositories = "favorite_repositories"
	}
}

extension UserDefaultsClient: DependencyKey {
	public static var liveValue: UserDefaultsClient {
		let ud = UserDefaults.standard
		ud.register(defaults: [.favoriteRepositories: Array<Repository.ID>()])
		return UserDefaultsClient(storage: ud)
	}

	public static var testValue: UserDefaultsClient {
		.init(storage: unimplemented("\(Self.self).storage"))
	}
}

extension DependencyValues {
	public var userDefaults: UserDefaultsClient {
		get { self[UserDefaultsClient.self] }
		set { self[UserDefaultsClient.self] = newValue }
	}
}

private extension UserDefaultsType {
	func object(forKey key: UserDefaultsClient.Key) -> Any? {
		object(forKey: key.rawValue)
	}

	func setValue(_ value: Any?, forKey key: UserDefaultsClient.Key) {
		setValue(value, forKey: key.rawValue)
	}
}

extension UserDefaults: UserDefaultsType {
	public func object(forKey key: UserDefaultsClient.Key) -> Any? {
		self.object(forKey: key.rawValue)
	}

	public func setValue(_ value: Any?, forKey key: UserDefaultsClient.Key) {
		self.setValue(value, forKey: key.rawValue)
	}

	func register(defaults: [UserDefaultsClient.Key: Any?]) {
		register(defaults: Dictionary(uniqueKeysWithValues: defaults.map({ ($0.key.rawValue, $0.value) })))
	}
}
