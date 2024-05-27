import Foundation

public func ordinal(_ n: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .ordinal
  return formatter.string(for: n) ?? ""
}

public func isPrime (_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
}

public func compose<A, B, C>(
  _ f: @escaping (B) -> C,
  _ g: @escaping (A) -> B
  )
  -> (A) -> C {

    return { (a: A) -> C in
      f(g(a))
    }
}

public func with<A, B>(_ a: A, _ f: (A) throws -> B) rethrows -> B {
  return try f(a)
}
