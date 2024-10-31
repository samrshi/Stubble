import MacroTesting
import SwiftSyntaxMacros
import XCTest
@testable import HammockMacros

final class StubbablePropertyTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
            macros: ["StubabbleProperty": StubbablePropertyMacro.self]
        ) {
            super.invokeTest()
        }
    }

    func testBasic() {
        assertMacro {
            """
            @StubabbleProperty
            var x: Int = 1
            """
        } expansion: {
            """
            var x: Int {
                @storageRestrictions(initializes: _x)
                init(initialValue) {
                    _x = initialValue
                }
                get {
                    if let _getX {
                        _x = _getX()
                    } else {
                        return _x
                    }
                }
                set {
                    if let _setX {
                        _setX(&_x, _x)
                    } else {
                        _x = newValue
                    }
                }
            }

            var _x: Int = 1

            var _getX: (() -> Int)? = nil

            var _setX: ((inout Int, Int) -> Void)? = nil
            """
        }
    }
}
