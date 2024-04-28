import Foundation

struct Math {
    static func isPrime(n: Int) -> Bool {
        if n < 2 { return false }
        if n == 2 || n == 3 { return true }
        
        let sqrtN = Int(sqrt(Double(n)))
        
        for i in 2...sqrtN {
            if n % i == 0 {
                return false
            }
        }
        
        return true
    }
    
    // 대량의 소수 판별할 때
//    static func isPrime(n: Int) -> Bool {
//        if n < 2 { return false }
//        
//        // array 1~n
//        var isPrimeArray = Array(repeating: true, count: n+1)
//        let sqrtN = Int(sqrt(Double(n)))
//        
//        for number in 2...sqrtN {
//            let isNumberPrime = isPrimeArray[number]
//            if !isNumberPrime { continue }
//            
//            for i in stride(from: number * 2, through: n, by: number) {
//                isPrimeArray[i] = false
//            }
//        }
//        
//        return isPrimeArray[n]
//    }
}
