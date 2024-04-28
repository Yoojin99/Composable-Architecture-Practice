//
//  ContentView.swift
//  SUPlayground
//
//  Created by jean.333 on 4/21/24.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CounterView(state: state)) {
                    Text("Counter demo")
                }
                
                NavigationLink(destination: FavoritePrimesView(state: state)) {
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
 ObservableObject 는 왜 struct 이면 안되는가?
 AnyObject 를 상속하고 있음 -> 근거가 있음.
 유지되는 단 하나의 source 를 원하는데 struct 로 만들게 되면
 상태값을 전달할 때마다 복사가 되기 때문.
 접근하는 모든 곳에서 동일한 값을 바라봐야 하기 때문에 class 이어야 합당함
 */
class AppState: ObservableObject, Codable  {
    // Combine 에서 온 개념. state 에 변화가 생길때 이 변화에 관심있는 subscriber 에게 알려줌
    @Published var count: Int = 0
    @Published var favoritePrimes: Set<Int> = []
    
    // listing properties we want to save
    enum CodingKeys: CodingKey {
        case count
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(count, forKey: .count)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        count = try container.decode(Int.self, forKey: .count)
    }
    
    init() {}
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
    @ObservedObject var state: AppState
    @State private var isPrimeModalShown: Bool = false
    @State private var nthPrimeNumber: Int? {
        didSet {
            if nthPrimeNumber != nil {
                isNthPrimeAlertShown = true
            }
        }
    }
    @State private var isNthPrimeAlertShown: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    state.count -= 1
                }, label: {
                    Text("-")
                })
                Text("\(state.count)")
                Button(action: {
                    state.count += 1
                }, label: {
                    Text("+")
                })
            }
            Button(action: { isPrimeModalShown = true }, label: {
                Text("Is this prime?")
            })
            
            Button(action: {
                nthPrime(state.count) { prime in
                    self.nthPrimeNumber = prime
                }
            }, label: {
                Text("What is the \(ordinal(state.count)) prime?")
            })
        }
        .font(.title)
        .navigationTitle("Counter Demo")
        // modal sheet. isPresented 가 자동으로 dismiss할때 false가 됨
        .sheet(isPresented: $isPrimeModalShown, content: {
            // 여기에 더 복잡한 로직을 추가하는 건 비추.
            // 더 indentation 이 들어갈수록 가독성이 떨어지며 이해가 어려움.
            // SU view 의 장점 중하나는 view 를 쪼개기 편하다는 것.
            IsPrimeModalView(state: state)
        })
        .alert("The \(ordinal(state.count)) prime is \(nthPrimeNumber ?? 0)", isPresented: $isNthPrimeAlertShown, actions: {
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
    @ObservedObject var state: AppState
    
    private var isSavedInFavoritePrimes: Bool {
        state.favoritePrimes.contains(state.count)
    }
    
    var body: some View {
        VStack {
            if Math.isPrime(n: state.count) {
                Text("\(state.count) is prime")
                
                Button(action: {
                    if isSavedInFavoritePrimes {
                        state.favoritePrimes.remove(state.count)
                    } else {
                        state.favoritePrimes.insert(state.count)
                    }
                }, label: {
                    if isSavedInFavoritePrimes {
                        Text("Remove from favorite primes")
                    } else {
                        Text("Save to favorite primes")
                    }
                })
            } else {
                Text("\(state.count) is not prime")
            }
        }
    }
}

struct FavoritePrimesView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        List {
            let favoritePrimes = state.favoritePrimes.sorted()
            
            ForEach(favoritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete(perform: { indexSet in
                let removedNumbers = indexSet.map{ favoritePrimes[$0] }
                
                for number in removedNumbers {
                    state.favoritePrimes.remove(number)
                }
            })
        }
        .navigationTitle("Favorite Primes")
    }
}

#Preview {
    ContentView(state: AppState())
}
