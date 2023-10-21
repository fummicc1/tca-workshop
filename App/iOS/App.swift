import SwiftUI
import ComposableArchitecture
import RepositoryListFeature

@main
struct TCAWorkshopApp: SwiftUI.App {
  var body: some Scene {
    WindowGroup {
        RepositoryListView(store: StoreOf<RepositoryList>(
            initialState: RepositoryList.State(),
            reducer: { RepositoryList() }
        ))
    }
  }
}
