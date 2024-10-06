import Foundation
import Hammock

@Stubbable
struct Mine {
    func x() {
        print("Production")
    }
    
    func asyncX() async throws {
        print("Production")
    }
    
    func yo() {
        print("x")
    }
}

var mine = Mine()
mine.x()
mine._x = { print("Stubbed!") }
mine.x()
