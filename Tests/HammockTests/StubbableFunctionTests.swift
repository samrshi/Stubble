import SwiftSyntaxMacros
import XCTest

import MacroTesting

@testable import HammockMacros

final class StubbableFunctionTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "StubbableFunction": StubbableMacro.self,
    ]
    
    override func invokeTest() {
        withMacroTesting(
            macros: ["StubbableFunction": StubbableFunctionMacro.self]
        ) {
            super.invokeTest()
        }
    }
    
    func testNoArgsVoid() {
        assertMacro {
            """
            @StubbableFunction
            func method() {
                print("production")
            }
            """
        } expansion: {
            """
            func method() {
                if let _method {
                    return _method()
                } else {
                    print("production")
                }
            }

            var _method: (() -> Void)? = nil
            """
        }
    }
    
    func testNoArgsReturn() {
        assertMacro {
            """
            @StubbableFunction
            func method() -> String {
                return "production"
            }
            """
        } expansion: {
            """
            func method() -> String {
                if let _method {
                    return _method()
                } else {
                    return "production"
                }
            }

            var _method: (() -> String)? = nil
            """
        }
    }
    
    func testNoArgsReturnWithoutKeyword() {
        assertMacro {
            """
            @StubbableFunction
            func method() -> String {
                "production"
            }
            """
        } expansion: {
            """
            func method() -> String {
                if let _method {
                    return _method()
                } else {
                    return "production"
                }
            }

            var _method: (() -> String)? = nil
            """
        }
    }
    
    func testFunctionsWithArgs() {
        assertMacro {
            """
            @StubbableFunction
            func singleNamedArg(x: String) {
                print(x)
            }
            
            @StubbableFunction
            func singleWildcardArg(_ x: String) {
                print(x)
            }
            
            @StubbableFunction
            func multipleArgs(x: String, _ y: String) {
                print(x + y)
            }
            """
        } expansion: {
            """
            func singleNamedArg(x: String) {
                if let _singleNamedArg {
                    return _singleNamedArg(x)
                } else {
                    print(x)
                }
            }

            var _singleNamedArg: ((String) -> Void)? = nil
            func singleWildcardArg(_ x: String) {
                if let _singleWildcardArg {
                    return _singleWildcardArg(x)
                } else {
                    print(x)
                }
            }

            var _singleWildcardArg: ((String) -> Void)? = nil
            func multipleArgs(x: String, _ y: String) {
                if let _multipleArgs {
                    return _multipleArgs(x, y)
                } else {
                    print(x + y)
                }
            }

            var _multipleArgs: ((String, String) -> Void)? = nil
            """
        }
    }
    
    func testVariadicFunction() {
        assertMacro {
            """
            @StubbableFunction
            func singleVariadicArg(x: String...) {
                print(x)
            }
            """
        } expansion: {
            """
            func singleVariadicArg(x: String...) {
                if let _singleVariadicArg {
                    return _singleVariadicArg(x)
                } else {
                    print(x)
                }
            }

            var _singleVariadicArg: (([String]) -> Void)? = nil
            """
        }
    }
    
    func testAsync() {
        assertMacro {
            """
            @StubbableFunction
            func asyncOnly() async {
                print("asyncOnly")
            }
            """
        } expansion: {
            """
            func asyncOnly() async {
                if let _asyncOnly {
                    return await _asyncOnly()
                } else {
                    print("asyncOnly")
                }
            }

            var _asyncOnly: (() async -> Void)? = nil
            """
        }
    }
    
    func testThrows() {
        assertMacro {
            """
            @StubbableFunction
            func throwsOnly() throws {
                print("throwsOnly")
            }
            """
        } expansion: {
            """
            func throwsOnly() throws {
                if let _throwsOnly {
                    return try _throwsOnly()
                } else {
                    print("throwsOnly")
                }
            }

            var _throwsOnly: (() throws -> Void)? = nil
            """
        }
    }
            
    
    func testAsyncThrows() {
        assertMacro {
            """
            @StubbableFunction
            func asyncThrows() async throws {
                print("asyncThrows")
            }
            """
        } expansion: {
            """
            func asyncThrows() async throws {
                if let _asyncThrows {
                    return try await _asyncThrows()
                } else {
                    print("asyncThrows")
                }
            }

            var _asyncThrows: (() async throws -> Void)? = nil
            """
        }
    }
    
    func testEmptyBody() {
        assertMacro {
            """
            @StubbableFunction
            func empty() {}
            """
        } expansion: {
            """
            func empty() {
                if let _empty {
                    return _empty()
                } else {
                }
            }

            var _empty: (() -> Void)? = nil
            """
        }
    }
    
    func testErrorGeneric() {
        assertMacro {
            """
            @StubbableFunction
            func generic<T>() {}
            """
        } diagnostics: {
            """
            @StubbableFunction
            func generic<T>() {}
                        ┬──
                        ╰─ 🛑 '@StubbableFunction' currently does not support generic functions
            """
        }
    }
    
    func testErrorNotFunction() {
        assertMacro {
            """
            class Class {
                @StubbableFunction
                init() {
                    print("init")
                }

                @StubbableFunction
                deinit {
                    print("deinit")
                }
            }
            """
        } diagnostics: {
            """
            class Class {
                @StubbableFunction
                ┬─────────────────
                ├─ 🛑 '@StubbableFunction' can only be applied to functions
                ╰─ 🛑 '@StubbableFunction' can only be applied to functions
                init() {
                    print("init")
                }

                @StubbableFunction
                ┬─────────────────
                ├─ 🛑 '@StubbableFunction' can only be applied to functions
                ╰─ 🛑 '@StubbableFunction' can only be applied to functions
                deinit {
                    print("deinit")
                }
            }
            """
        }
    }
}
