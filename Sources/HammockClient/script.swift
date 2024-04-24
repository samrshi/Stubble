import Foundation
import Hammock

@Mockable
class NetworkService {
    func makeRequest() async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://learning.appteamcarolina.com/networking-demo/apprentice")!)
        return try JSONDecoder().decode(String.self, from: data)
    }
}

func test(_ service: NetworkService) async {
    do {
        print(try await service.makeRequest())
    } catch {
        print("Error")
    }
}

@main
struct Main {
    static func main() async {
        let mock = NetworkService.Mock()
        await test(mock)
        mock._makeRequest = { "Mocked!" }
        await test(mock)
        mock._makeRequest = { throw NSError(domain: "HammockMain", code: 1) }
        await test(mock)
    }
}
