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

private func ordinal(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .ordinal
    return formatter.string(for: n) ?? ""
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
 State mutation : 현재 state 가 있고, 어떤 유저 액션이 들어오면 새로운 버전의 state 를 만드는 것. 즉 함수같이 현재 상태와 입력값이 주어지면 다음 상태를 리턴할 수 있는 것.
 
 그렇다면 유저 액션을 data 로 표현하기 위해서는? enum이 적합함. 사용자 액션은 다양하고, 각 목록을 나열할 수 있으며 모든 액션을 다 표현할 수 있기 때문임.
 */

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
}

/*
 reducer인 이유? array.reduce() 메서드와 비슷. 초기값이 주어지고 각 원소마다 연산을 수행해서 새로운 상태를 반환하기 때문.
 
 매번 새로운 state 를 리턴하는데, 여러 mutation 을 한 번에 받아서 처리하지 않기 때문에 아래와 같이 중첩해서 작성해야 함.
 
 let state = AppState()
 counterReducer(
     state: counterReducer(
         state: state,
         action: .decrTapped),
     action: .incrTapped)
 
 시간에 따라 변하는 state 를 관리할 로직은? store 에서 처리 가능
 */
/*
 AppState 자체는 굉장히 클 수 있고 사용자 액션이 들어올 때마다 매번 state 의 새로운 copy 를 생성하는게 scalable 하지 않을 것
 (A) -> (A) == (inout A) -> Void
 (A, B) -> (A, C) == (inout A, B) -> C

 아래 코드에서는 copy 를 생성하는 boilerplate 코드/ 생성할 필요도 없을 뿐더러 수정 연산도 가능하다는 장점이 있음
 */
/*
 AppState 를 다루고 있기 때문에 action 도 counter 에 국한되지 않고 reducer 자체도 appReducer 가 되는 것이 합당함
 */
func appReducer(state: inout AppState, action: AppAction) {
    switch action {
    case .counter(.decrTapped):
        state.count -= 1
    case .counter(.incrTapped):
        state.count += 1
    case .primeModal(.saveFavoritePrimeTapped):
        state.favoritePrimes.insert(state.count)
        state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))
    case .primeModal(.removeFavoritePrimeTapped):
        state.favoritePrimes.remove(state.count)
        state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))
    case .favoritePrimes(.deleteFavoritePrimes(let indexSet)):
        // side effect? 화면에 노출되는 폼이랑 완전히 통일해야 추후 문제 없을듯
        let favoritePrimes = state.favoritePrimes.sorted()
        let removedNumbers = indexSet.map{ favoritePrimes[$0] }
        
        for number in removedNumbers {
            state.favoritePrimes.remove(number)
            state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(number)))
        }
    }
}


final class Store<Value, Action>: ObservableObject {
    let reducer: (inout Value, Action) -> Void
    @Published var value: Value
    
    init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
        self.value = initialValue
        self.reducer = reducer
    }
    
    // 연산을 view 에서 떼내고, reducer 내부로 옮겨버림
    // view 내부에 연산은 오직 send(userAction) 메서드를 통해서만 이루어짐
    // 일관된 방법을 제공한다
    func send(_ action: Action) {
        reducer(&self.value, action)
    }
}

struct CounterView: View {
    // @State 는 hyper local state 를 위한 것
    // 외부로 나갔다 다시 들어올 경우 state 를 잃어버림
    // view 계층의 위-아래를 왔다갔다 할 때 유지하기 위한 다른 장치가 필요
    // 이때 사용할 수 있는게 obejct binding
    /*
     Object binding : @State 와 거의 비슷, except
     * 어떻게 변화가 일어나는지
     * Swift UI 시스템에 어떻게 이 변화를 알리는지
     를 정할 책임이 나한테 있음
     이는 local 하기보다는 global 변수를 선언하는 것과 비슷함.
     그래서 앱 전역에서 상태를 유지할 수 있음
     */
    /*
     @ObservedObject var count: Int = 0 의 문제
     1. 0. 처음 화면에 진입했을 때는 0이겠지만 그 다음에는 마지막으로 우리가 수정한 상태값이어야 함
     2. @ObservedObject 에 사용되는 것은 Observable Object 프로토콜을 따라야 함. Int 를 extend 하기보다는 우리가 제어하는 상태값 자체가 bindable object가 되기를 바람.
     */
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
    
    // MARK: 문제 1
    // state 의 변경 연산이 많음.
    // 일부는 localState, 일부는 global state, 또 two-way binding 을 통해 자동으로 상태가 변경되는 경우도 있음
    // 이런 상태 변경 연산들이 view 에 골고루 퍼져있음
    // 이 코드를 처음보는 사람은 상태 변경하는 코드를 어디에 추가해야 할지 마땅한 장소를 찾기 어려움
    // 명시적으로 inline / action handler / two-way binding 중 어떤 것?
    // in line mutations / 또한 imperative 하며 declarative 하지 않음
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    store.send(.counter(.decrTapped))
//                    // 직접 state 에 연산을 하는 것보다 이렇게 하는 것이 좋은 이유
//                    // 여기서 사용자가 하는게 무엇인지를 설명하고 이를 함수에 전달하는 것!
//                    // 이는 사용자 액션을 declarative 하게 정의했다고 할 수 있음
//                    // 즉 연산을 하기보다는 사용자의 액션을 정의했다고 할 수 있음
//                    // 연산은 reducer 함수에 넣어둠으로써 연산에 적합한 장소를 찾은 것
//                    self.store.value = counterReducer(state: self.store.value, action: .decrTapped)
////                    store.value.count -= 1
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
                // MARK: 문제 1
                // step by step 으로 수행하고 있음.
                // SU는 body 프로퍼티를 통해 가장 간단한 방법으로 view 를 표현하고 있으며 개발자는 view 계층에만 집중할 수 있음
                // 이는 view 를 이해하기 쉽게 만들며 변경을 쉽게하며 테스트를 쉽게 만듦
                // 근데 아래 button disable 시키는 로직은 더러워 보임. 클로저 내부에 로직이 넘치고 있고 view 의 declarative 한 성질(view 계층에 단순히 state 를 연결하는 것)을 죽이고 있음
                // helper function 을 따로 뺄 수 있는데 이러면 또 helper function 으로 빼지 않은 곳과 코드 작성 방식이 달라지게 되며 팀은 helper 함수로 빼야 할 경우의 가이드라인을 작성해야 할 것임.
                // 가장 큰 문제는 이렇게 연산이 흩뿌려져 있을 수록 싱크가 안맞기 더 쉬워진다는 것임
                isNthPrimeButtonDisabled = true
                // MARK: 문제 3
                // 제어할 수 없음 : 취소, throttle 할 수 있는 방법 없으며 테스트도 안됨.
                // side effect 를 수행하는 방법은 우리한테 달려있음
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

func nthPrime(_ n: Int, callback: @escaping (Int?) -> Void) -> Void {
    WolframDataSource().wolframAlpha(query: "prime \(n)") { result in
    callback(
      result
        .flatMap {
          $0.queryresult
            .pods
            .first(where: { $0.primary == .some(true) })?
            .subpods
            .first?
            .plaintext
      }
      .flatMap(Int.init)
    )
  }
}

struct IsPrimeModalView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    
    private var isSavedInFavoritePrimes: Bool {
        store.value.favoritePrimes.contains(store.value.count)
    }
    
    var body: some View {
        VStack {
            if Math.isPrime(n: store.value.count) {
                Text("\(store.value.count) is prime")
                
                Button(action: {
                    if isSavedInFavoritePrimes {
                        store.send(.primeModal(.removeFavoritePrimeTapped))
                    } else {
                        store.send(.primeModal(.saveFavoritePrimeTapped))
//                        store.value.favoritePrimes.insert(store.value.count)
//                        // MARK: 문제 2
//                        // activityFeed 에 추가하는 건 여기서만이 아니라 Favorite Primes 화면에서도 수행해야 함!
//                        // 근데 이를 개발자의 실수로 잊어먹기 쉬움
//                        // AppState 에 한번에 수행하는 함수를 추가할 수도 있음. 이러면 상태를 변경하는 방법이 세가지임
//                        // 1. inline 2. action block 3. struct 에 메서드 추가
//                        // 팀은 이거에 대해 가이드라인을 또 작성해야 하고 Apple 은 이런 방법에 대해 명시적인 가이드라인을 제공하고 있지 않음
//                        store.value.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(store.value.count)))
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
    // MARK: 문제 4 : state 가 composable 하지 않음.
    // state 의 일부만 가져올 수는 없는가?
    // 우리가 원하는 것만 알 수 있게 한다면 이 view 를 별도로 분리해서 완전히 고립되게 할 수 있음
    // 이러면 이해하기 쉽고, 고립되어 있기 때문에 다른 요소를 생각할 필요 없음. modular application design 의 원칙임
    // 이 view 를 완전히 고립시켜서 다른 ui 에 쉽게 plug in 할 수 있게 하는 것.
    @ObservedObject var store: Store<AppState, AppAction>
    
    var body: some View {
        List {
            let favoritePrimes = store.value.favoritePrimes.sorted()
            
            ForEach(favoritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete(perform: { indexSet in
                let removedNumbers = indexSet.map{ favoritePrimes[$0] }
                
                for number in removedNumbers {
                    store.value.favoritePrimes.remove(number)
                    store.value.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(number)))
                }
            })
        }
        .navigationTitle("Favorite Primes")
    }
}

#Preview {
    ContentView(store: Store<AppState, AppAction>(initialValue: AppState(), reducer: appReducer(state:action:)))
}
