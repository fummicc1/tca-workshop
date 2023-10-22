import Foundation

public struct MockUserDefaults: UserDefaultsType {

	var onObject: (_ forKey: UserDefaultsClient.Key) -> Any?
	var onSet: (_: Any?, _ forKey: UserDefaultsClient.Key) -> Void

	public init(
		onObject: @escaping (_: UserDefaultsClient.Key) -> Any?,
		onSet: @escaping (_: Any?, _: UserDefaultsClient.Key) -> Void
	) {
		self.onObject = onObject
		self.onSet = onSet
	}

	public func object(forKey key: UserDefaultsClient.Key) -> Any? {
		onObject(key)
	}

	public func setValue(_ value: Any?, forKey key: UserDefaultsClient.Key) {
		onSet(value, key)
	}

	// not implement
	public func object(forKey key: String) -> Any? {
		fatalError()
	}

	public func setValue(_ value: Any?, forKey key: String) {
		fatalError()
	}
}
