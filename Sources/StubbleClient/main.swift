import Foundation
import Observation
import Stubble

struct Classroom: Codable, Identifiable {
    let id: UUID
    let building: String
    let number: String
    let description: String?
}

@Stubbable
class Service {
    func makeRequest() async throws -> Classroom {
        let url = URL(string: "https://learning.appteamcarolina.com/networking-demo/classrooms")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let classrooms = try JSONDecoder().decode([Classroom].self, from: data)
        return classrooms.first!
    }
}

let service = Service()

// Production response
print(try await service.makeRequest())

service._makeRequest = { return Classroom(id: UUID(), building: "HELLO", number: "WORLD", description: nil) }
print(try await service.makeRequest())
