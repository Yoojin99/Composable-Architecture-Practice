import Foundation

protocol PrimeDataSource {}

private let wolframAlphaApiKey = "6H69Q3-828TKQJ4EP"

final class WolframDataSource {
    func wolframAlpha(query: String, callback: @escaping (WolframPrimeResult?) -> Void) -> Void {
      var components = URLComponents(string: "https://api.wolframalpha.com/v2/query")!
      components.queryItems = [
        URLQueryItem(name: "input", value: query),
        URLQueryItem(name: "format", value: "plaintext"),
        URLQueryItem(name: "output", value: "JSON"),
        URLQueryItem(name: "appid", value: wolframAlphaApiKey),
      ]

      URLSession.shared.dataTask(with: components.url(relativeTo: nil)!) { data, response, error in
        callback(
          data
            .flatMap { try? JSONDecoder().decode(WolframPrimeResult.self, from: $0) }
        )
      }
      .resume()
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
