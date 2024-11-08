//
//  File.swift
//  Stubble
//
//  Created by Samuel Shi on 11/7/24.
//

import Foundation
import Testing

struct Course {}

struct Student: Equatable {
    let name: String
    let graduationYear: Int
}

protocol RosterServiceProtocol {
    func fetchStudents() -> [Student]
}

class RosterService: RosterServiceProtocol {
    func fetchStudents() -> [Student] {
        // make an HTTP response
        return []
    }
}

class RosterServiceStub: RosterServiceProtocol {
    var students: [Student] = []

    func fetchStudents() -> [Student] {
        return students
    }
}

@Observable
class RosterViewModel {
    let service: RosterServiceProtocol

    init(service: RosterServiceProtocol) {
        self.service = service
    }

    func studentsByGraduation() -> [Int: [Student]] {
        let students = service.fetchStudents()
        let grouped = Dictionary(grouping: students, by: \.graduationYear)
        return grouped
    }
}

@Test
func testEmptyRoster() async throws {
    let sam = Student(name: "Sam", graduationYear: 2024)
    let morgan = Student(name: "Morgan", graduationYear: 2025)

    let stub = RosterServiceStub()
    stub.students = [sam, morgan]

    let vm = RosterViewModel(service: stub)
    let grouped = vm.studentsByGraduation()
    #expect(grouped == [2024: [sam], 2025: [morgan]])
}
