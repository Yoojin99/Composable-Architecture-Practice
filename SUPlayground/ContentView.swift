//
//  ContentView.swift
//  SUPlayground
//
//  Created by jean.333 on 4/21/24.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var store: Store<AppState, AppAction>

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CounterView(store: store)) {
                    Text("Counter demo")
                }
                
                NavigationLink(destination: FavoritePrimesView(store: store)) {
                    Text("Favorite Primes")
                }
            }
            .navigationTitle("State Management")
        }
    }
}

/*
 class -> struct. Decoupled state from combine, SwiftUI framework, 그래서 리눅스같은 곳에서도 이 구조체를 따로 가져다 쓸 수 있음.
 값 타입으로 변한 것 자체가 큰 장점. 
 */
struct AppState: Codable  {
    // Combine 에서 온 개념. state 에 변화가 생길때 이 변화에 관심있는 subscriber 에게 알려줌
    var count: Int = 0
    var favoritePrimes: Set<Int> = []
    var loggedInUser: User?
    var activityFeed: [Activity] = []
    
    // listing properties we want to save
    enum CodingKeys: CodingKey {
        case count
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(count, forKey: .count)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        count = try container.decode(Int.self, forKey: .count)
    }
    
    init() {}
    
    struct User {
        let id: Int
        let name: String
        let bio: String
    }
    
    struct Activity {
        let timestamp: Date
        let type: ActivityType
        
        enum ActivityType {
            case addedFavoritePrime(Int)
            case removedFavoritePrime(Int)
        }
    }
}

/*
 action 의 enum 분리를 통해 modularity 확보
 */

enum CounterAction {
    case decrTapped
    case incrTapped
}

enum PrimeModalAction {
    case saveFavoritePrimeTapped
    case removeFavoritePrimeTapped
}

enum FavoritePrimesAction {
    case deleteFavoritePrimes(IndexSet)
}

enum AppAction {
    case counter(CounterAction)
    case primeModal(PrimeModalAction)
    case favoritePrimes(FavoritePrimesAction)
    
    var counter: CounterAction? {
        get {
            guard case let .counter(value) = self else {
                return nil
            }
            return value
        }
        set {
            guard case .counter = self, let newValue = newValue else { return }
            self = .counter(newValue)
        }
    }
    
    var primeModal: PrimeModalAction? {
        get {
            guard case let .primeModal(value) = self else {
                return nil
            }
            return value
        }
        set {
            guard case .primeModal = self, let newValue = newValue else { return }
            self = .primeModal(newValue)
        }
    }
    
    var favoritePrimes: FavoritePrimesAction? {
        get {
            guard case let .favoritePrimes(value) = self else {
                return nil
            }
            return value
        }
        set {
            guard case .favoritePrimes = self, let newValue = newValue else { return }
            self = .favoritePrimes(newValue)
        }
    }
}

func counterReducer(state: inout Int, action: CounterAction) {
    switch action {
    case .decrTapped:
        // 이 함수를 처음 본 개발자는 이 reducer 가 단순히 int 만 조작한다는 것을 알고, 쓸데없이 전체 appstate 내부의 값을 수정하지 않을 것임
        state -= 1
    case .incrTapped:
        state += 1
    }
}

func primeModalReducer(state: inout AppState, action: PrimeModalAction) {
    switch action {
    case .saveFavoritePrimeTapped:
        state.favoritePrimes.insert(state.count)
    case .removeFavoritePrimeTapped:
        state.favoritePrimes.remove(state.count)
    }
}

func favoritePrimesReducer(state: inout Set<Int>, action: FavoritePrimesAction) {
    switch action {
    case .deleteFavoritePrimes(let indexSet):
        let favoritePrimes = state.sorted()
        let removedNumbers = indexSet.map{ favoritePrimes[$0] }
        
        for number in removedNumbers {
            state.remove(number)
        }
    }
}

func combine<Value, Action>(
    _ reducers: (inout Value, Action) -> Void...
) -> (inout Value, Action) -> Void {
    return { value, action in
        for reducer in reducers {
            reducer(&value, action)
        }
    }
}

final class Store<Value, Action>: ObservableObject {
    let reducer: (inout Value, Action) -> Void
    @Published private(set) var value: Value
    
    init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
        self.value = initialValue
        self.reducer = reducer
    }
    
    func send(_ action: Action) {
        reducer(&self.value, action)
    }
}

func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction>(
    _ reducer: @escaping (inout LocalValue, LocalAction) -> Void,
    value: WritableKeyPath<GlobalValue, LocalValue>,
    action: WritableKeyPath<GlobalAction, LocalAction?>
) -> (inout GlobalValue, GlobalAction) -> Void {
    return { globalValue, globalAction in
        guard let localAction = globalAction[keyPath: action] else {
            return
        }
        reducer(&globalValue[keyPath: value], localAction)
    }
}

struct _KeyPath<Root, Value> {
    let get: (Root) -> Value
    let set: (inout Root, Value) -> Void
}

struct EnumKeyPath<Root, Value> {
    let embed: (Value) -> Root
    let extract: (Root) -> Value?
}

func activityFeed(
    _ reducer: @escaping (inout AppState, AppAction) -> Void
) -> (inout AppState, AppAction) -> Void {
    return { state, action in
        switch action {
            
        case .counter:
            break
        case .primeModal(.removeFavoritePrimeTapped):
            state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))
        case .primeModal(.saveFavoritePrimeTapped):
            state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))
        case let .favoritePrimes(.deleteFavoritePrimes(removedNumbers)):
            for number in removedNumbers {
                state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(number)))
            }
        }
        
        reducer(&state, action)
    }
}

let appReducer: (inout AppState, AppAction) -> Void = combine(
    pullback(counterReducer, value: \.count, action: \.counter),
    pullback(primeModalReducer, value: \.self, action: \.primeModal),
    pullback(favoritePrimesReducer, value: \.favoritePrimes, action: \.favoritePrimes)
)

func logging<Value, Action>(
    _ reducer: @escaping (inout Value, Action) -> Void
) -> (inout Value, Action) -> Void {
    return { value, action in
        reducer(&value, action)
        print("Action: \(action)")
        print("Value:")
        dump(value)
        print("---")
    }
}

struct CounterView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    @State private var isPrimeModalShown: Bool = false
    @State private var nthPrimeNumber: Int? {
        didSet {
            if nthPrimeNumber != nil {
                isNthPrimeAlertShown = true
            }
        }
    }
    @State private var isNthPrimeAlertShown: Bool = false
    @State private var isNthPrimeButtonDisabled = false
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    store.send(.counter(.decrTapped))
                }, label: {
                    Text("-")
                })
                Text("\(store.value.count)")
                Button(action: { store.send(.counter(.incrTapped)) }, label: {
                    Text("+")
                })
            }
            Button(action: { isPrimeModalShown = true }, label: {
                Text("Is this prime?")
            })
            
            Button(action: {
                isNthPrimeButtonDisabled = true
                nthPrime(store.value.count) { prime in
                    isNthPrimeButtonDisabled = false
                    self.nthPrimeNumber = prime
                }
            }, label: {
                Text("What is the \(ordinal(store.value.count)) prime?")
            })
            .disabled(isNthPrimeButtonDisabled)
        }
        .font(.title)
        .navigationTitle("Counter Demo")
        // modal sheet. isPresented 가 자동으로 dismiss할때 false가 됨
        // isPrimeModalShown 은 시트가 내려갈 경우 자동으로 변경됨
        .sheet(isPresented: $isPrimeModalShown, content: {
            // 여기에 더 복잡한 로직을 추가하는 건 비추.
            // 더 indentation 이 들어갈수록 가독성이 떨어지며 이해가 어려움.
            // SU view 의 장점 중하나는 view 를 쪼개기 편하다는 것.
            IsPrimeModalView(store: store)
        })
        .alert("The \(ordinal(store.value.count)) prime is \(nthPrimeNumber ?? 0)", isPresented: $isNthPrimeAlertShown, actions: {
            Button(role: .cancel, action: {}) {
                Text("Ok")
            }
        })
    }
}

struct IsPrimeModalView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    
    private var isSavedInFavoritePrimes: Bool {
        store.value.favoritePrimes.contains(store.value.count)
    }
    
    var body: some View {
        VStack {
            if isPrime(store.value.count) {
                Text("\(store.value.count) is prime")
                
                Button(action: {
                    if isSavedInFavoritePrimes {
                        store.send(.primeModal(.removeFavoritePrimeTapped))
                    } else {
                        store.send(.primeModal(.saveFavoritePrimeTapped))
                    }
                }, label: {
                    if isSavedInFavoritePrimes {
                        Text("Remove from favorite primes")
                    } else {
                        Text("Save to favorite primes")
                    }
                })
            } else {
                Text("\(store.value.count) is not prime")
            }
        }
    }
}

struct FavoritePrimesView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    
    var body: some View {
        List {
            let favoritePrimes = store.value.favoritePrimes.sorted()
            
            ForEach(favoritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete(perform: { indexSet in
                self.store.send(.favoritePrimes(.deleteFavoritePrimes(indexSet)))
            })
        }
        .navigationTitle("Favorite Primes")
    }
}

#Preview {
    ContentView(
        store: Store(
            initialValue: AppState(),
            reducer: with(
                appReducer,
                compose(
                    logging,
                    activityFeed
                )
            )
        )
    )
}
