import Entity
import XCTestDynamicOverlay
import Dependencies
import Foundation

public struct GitHubAPIClient {
    // 型に名前付きパラメータは使えない
    public var searchRepositories: @Sendable (_ query: String) async throws -> [Repository]
}

extension GitHubAPIClient: DependencyKey {
  public static let liveValue = Self(
    searchRepositories: { query in
      let url = URL(
        string: "https://api.github.com/search/repositories?q=\(query)&sort=stars"
      )!
      var request = URLRequest(url: url)
      if let token = Bundle.main.infoDictionary?["GitHubPersonalAccessToken"] as? String {
        request.setValue(
          "Bearer \(token)",
          forHTTPHeaderField: "Authorization"
        )
      }
      let (data, _) = try await URLSession.shared.data(for: request)
      let repositories = try jsonDecoder.decode(
        GithubSearchResult.self,
        from: data
      ).items
      return repositories
    }
  )
}

extension GitHubAPIClient: TestDependencyKey {
    public static var testValue: GitHubAPIClient {
        Self.init(
            searchRepositories: unimplemented("\(Self.self).searchRepositories")
        )
    }
}

extension DependencyValues {
  public var gitHubAPIClient: GitHubAPIClient {
    get { self[GitHubAPIClient.self] }
    set { self[GitHubAPIClient.self] = newValue }
  }
}

private let jsonDecoder: JSONDecoder = {
  let decoder = JSONDecoder()
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  return decoder
}()
