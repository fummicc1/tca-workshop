import Foundation
import SwiftUI
import Entity
import ComposableArchitecture

public struct RepositoryRow: Reducer {
    public struct State: Equatable, Identifiable {
        var repository: Repository

        public var id: Int { repository.id }
        public init(repository: Repository) {
            self.repository = repository
        }
    }
    public enum Action: Equatable {
        case rowTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case rowTapped
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .rowTapped:
                return .send(.delegate(.rowTapped))
            case .delegate(.rowTapped):
                return .none
            }
        }
    }

    public init() {}
}


public struct RepositoryRowView: View {
    var store: StoreOf<RepositoryRow>

    init(store: StoreOf<RepositoryRow>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Button {
                viewStore.send(.rowTapped)
                  } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewStore.repository.fullName)
                        .font(.title2.bold())
                        Text(viewStore.repository.description ?? "")
                        .font(.body)
                        .lineLimit(2)
                      HStack(alignment: .center, spacing: 32) {
                        Label(
                          title: {
                              Text("\(viewStore.repository.stargazersCount)")
                              .font(.callout)
                          },
                          icon: {
                            Image(systemName: "star.fill")
                              .foregroundStyle(.yellow)
                          }
                        )
                        Label(
                          title: {
                              Text(viewStore.repository.language ?? "")
                              .font(.callout)
                          },
                          icon: {
                            Image(systemName: "text.word.spacing")
                              .foregroundStyle(.gray)
                          }
                        )
                      }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  .buttonStyle(.plain)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    RepositoryRowView(store: StoreOf<RepositoryRow>(
        
        initialState: RepositoryRow.State(
            repository: .mock(id: 1)),
        reducer: { RepositoryRow() }
    ))
    .padding()
}
