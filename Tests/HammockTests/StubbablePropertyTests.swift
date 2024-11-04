import MacroTesting
import SwiftSyntaxMacros
import XCTest
@testable import HammockMacros

final class StubbablePropertyTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
            macros: ["StubbableProperty": StubbablePropertyMacro.self]
        ) {
            super.invokeTest()
        }
    }

    func testBasic() {
        assertMacro {
            """
            @StubbableProperty
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
                        return _getX()
                    } else {
                        return _x
                    }
                }
                set {
                    if let _setX {
                        _setX(&_x, newValue)
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
