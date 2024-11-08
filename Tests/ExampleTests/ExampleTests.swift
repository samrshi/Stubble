// import Foundation
// import Testing
// import Stubble
//
// struct Student: Codable {
//    let name: String
// }
//
// struct CourseRoster: Codable {
//    let students: [Student]
// }
//
// @Stubbable
// private class RosterService {
//    func fetchAllRosters() async throws -> [CourseRoster] {
//        let url = URL(string: "https://api.samuelshi.com/rosters")!
//        let (data, _) = try await URLSession.shared.data(from: url)
//        return try JSONDecoder().decode([CourseRoster].self, from: data)
//    }
// }
//
// @Observable
// private class RosterViewModel {
//    let service = RosterService()
//
//    var totalStudents: Int?
//    var rosters: [CourseRoster]?
//
//    func fetch() async throws {
//        let rosters = try await service.fetchAllRosters()
//        self.rosters = rosters
//        self.totalStudents = rosters.reduce(0) { $0 + $1.students.count }
//    }
// }
//
// @Test
// func testEmptyResponse() async throws {
//    let vm = RosterViewModel()
//
//    vm.service._fetchAllRosters = { return [] }
//    try await vm.fetch()
//
//    #expect(vm.totalStudents == 0)
// }
//
// @Test
// func testEmptyRosters() async throws {
//    let vm = RosterViewModel()
//
//    let emptyRosters = [CourseRoster](repeating: CourseRoster(students: []), count: 10)
//    vm.service._fetchAllRosters = { return emptyRosters }
//
//    try await vm.fetch()
//    #expect(vm.totalStudents == 0)
// }
//
// @Test
// func testSingleRosters() async throws {
//    let vm = RosterViewModel()
//
//    let sam = Student(name: "Sam"), jane = Student(name: "Jane")
//    let nonEmptyRosters = [CourseRoster](repeating: CourseRoster(students: [sam, jane]), count: 10)
//    vm.service._fetchAllRosters = { return nonEmptyRosters }
//
//    try await vm.fetch()
//    #expect(vm.totalStudents == 20)
// }
