import Foundation
import Hammock
import Observation

@Stubbable
class Service {
    func makeRequest() -> String {
        return "production response"
    }
}
