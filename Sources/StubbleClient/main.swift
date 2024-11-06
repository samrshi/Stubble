import Foundation
import Stubble
import Observation

@Stubbable
class Service {
    func makeRequest() -> String {
        return "production response"
    }
}
