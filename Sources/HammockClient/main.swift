import Foundation
import Hammock
import Observation

@Observable
class Foo {
    var x: Int
    
    init(x: Int) {
        self.x = x
    }
}

class NS {
    var _x: [String] = ["prod"]
    
    var x: [String] = ["prod"] {
        @storageRestrictions(initializes: _x)
        init(initialValue) {
            _x = initialValue
        }
        get {
            print("getting")
            if let _getX {
                return _getX(_x)
            } else {
                return _x
            }
        }
        set {
            print("setting")
            if let _setX {
                _setX(&_x, newValue)
            } else {
                _x = newValue
            }
        }
    }
    
    var _getX: (([String]) -> [String])? = nil
    var _setX: ((inout [String], [String]) -> Void)? = nil
}

var myX: [String] = ["stubbed"]

let ns = NS()
print(ns.x)
ns._getX = { _ in myX }
print(ns.x)
ns.x = ["new"]
print(ns.x)
ns._setX = { property, newValue in
    myX = newValue
}
ns.x.append("appended")
print(ns.x)
