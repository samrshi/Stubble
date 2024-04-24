import Hammock

@Mockable
class NetworkService {
    func makeRequest() -> String {
        return "Production"
    }
    
    func display(_ value: String) {
        print(value)
    }
}

func test(_ ns: NetworkService) {
    print(ns.makeRequest())
    ns.display("Hello")
}

let mock = NetworkService.Mock()
mock._makeRequest = { return "Mocked" }
mock._display = { print("Mocked: \($0)") }
test(mock)
