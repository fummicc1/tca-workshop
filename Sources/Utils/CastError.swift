import Foundation

public struct CastError<Value, To>: LocalizedError {

	var value: Value
	var to: To

	public init(value: Value, to: To) {
		self.value = value
		self.to = to
	}

	public var errorDescription: String? {
		"Failed to cast value \(value) into \(to.self)."
	}
}
