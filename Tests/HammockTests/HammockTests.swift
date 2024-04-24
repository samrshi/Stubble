import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(HammockMacros)
import HammockMacros

let testMacros: [String: Macro.Type] = [
    "stringify": StringifyMacro.self,
    "Mockable": MockableMacro.self
]
#endif

final class HammockTests: XCTestCase {
    func testBasicClass() {
        #if canImport(HammockMacros)
        assertMacroExpansion(
            """
            @Mockable
            class NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """,
            expandedSource: """
            class NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            
                class Mock: NetworkService {
                    var _makeRequest: (() -> String)? = nil
            
                    override func makeRequest() -> String {
                        if let peer = _makeRequest {
                            peer()
                        } else {
                            super.makeRequest()
                        }
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testWildcardParameter() {
        #if canImport(HammockMacros)
        assertMacroExpansion(
            """
            @Mockable
            class NetworkService {
                func makeRequest(_ param1: Int, param2: Int) -> String {
                    return "Production"
                }
            }
            """,
            expandedSource: """
            class NetworkService {
                func makeRequest(_ param1: Int, param2: Int) -> String {
                    return "Production"
                }

                class Mock: NetworkService {
                    var _makeRequest: ((Int, Int) -> String)? = nil
            
                    override func makeRequest(_ param1: Int, param2: Int) -> String {
                        if let peer = _makeRequest {
                            peer(param1, param2)
                        } else {
                            super.makeRequest(param1, param2: param2)
                        }
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testStaticSkipping() {
        #if canImport(HammockMacros)
        assertMacroExpansion(
            """
            @Mockable
            class NetworkService {
                static func makeRequest() -> String {
                    return "Production"
                }
            }
            """,
            expandedSource: """
            class NetworkService {
                static func makeRequest() -> String {
                    return "Production"
                }
            
                class Mock: NetworkService {
                }
            }
            """,
            macros: testMacros
        )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testTwoMethods() {
        #if canImport(HammockMacros)
        assertMacroExpansion(
            """
            @Mockable
            class NetworkService {
                func methodOne() {
                    print("one")
                }
            
                func methodTwo() {
                    print("two")
                }
            }
            """,
            expandedSource: """
            class NetworkService {
                func methodOne() {
                    print("one")
                }
            
                func methodTwo() {
                    print("two")
                }
            
                class Mock: NetworkService {
                    var _methodOne: (() -> Void)? = nil
            
                    override func methodOne() {
                        if let peer = _methodOne {
                            peer()
                        } else {
                            super.methodOne()
                        }
                    }
            
                    var _methodTwo: (() -> Void)? = nil
            
                    override func methodTwo() {
                        if let peer = _methodTwo {
                            peer()
                        } else {
                            super.methodTwo()
                        }
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testAsyncThrows() {
        #if canImport(HammockMacros)
        assertMacroExpansion(
            """
            @Mockable
            class NetworkService {
                func funcAsyncThrows() async throws -> String {
                    return "Return Value"
                }
            
                func funcAsync() async -> String {
                    return "Return Value"
                }
            
                func funcThrows() throws -> String {
                    return "Return Value"
                }
            }
            """,
            expandedSource: """
            class NetworkService {
                func funcAsyncThrows() async throws -> String {
                    return "Return Value"
                }
            
                func funcAsync() async -> String {
                    return "Return Value"
                }
            
                func funcThrows() throws -> String {
                    return "Return Value"
                }

                class Mock: NetworkService {
                    var _funcAsyncThrows: (() async throws -> String)? = nil
            
                    override func funcAsyncThrows() async throws -> String {
                        if let peer = _funcAsyncThrows {
                            try await peer()
                        } else {
                            try await super.funcAsyncThrows()
                        }
                    }
            
                    var _funcAsync: (() async -> String)? = nil
            
                    override func funcAsync() async -> String {
                        if let peer = _funcAsync {
                            await peer()
                        } else {
                            await super.funcAsync()
                        }
                    }
            
                    var _funcThrows: (() throws -> String)? = nil
            
                    override func funcThrows() throws -> String {
                        if let peer = _funcThrows {
                            try peer()
                        } else {
                            try super.funcThrows()
                        }
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testFinalClass() {
        #if canImport(HammockMacros)
        assertMacroExpansion(
            """
            @Mockable
            final class NetworkService {
                func makeRequest() -> String {
                    return "Final"
                }
            }
            """,
            expandedSource: """
            final class NetworkService {
                func makeRequest() -> String {
                    return "Final"
                }
            }
            """,
            diagnostics: [.init(message: "classIsFinal", line: 1, column: 1)],
            macros: testMacros
        )
        #else
            throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
//    func testMacro() throws {
//        #if canImport(HammockMacros)
//        assertMacroExpansion(
//            """
//            #stringify(a + b)
//            """,
//            expandedSource: """
//            (a + b, "a + b")
//            """,
//            macros: testMacros
//        )
//        #else
//        throw XCTSkip("macros are only supported when running tests for the host platform")
//        #endif
//    }
//
//    func testMacroWithStringLiteral() throws {
//        #if canImport(HammockMacros)
//        assertMacroExpansion(
//            #"""
//            #stringify("Hello, \(name)")
//            """#,
//            expandedSource: #"""
//            ("Hello, \(name)", #""Hello, \(name)""#)
//            """#,
//            macros: testMacros
//        )
//        #else
//        throw XCTSkip("macros are only supported when running tests for the host platform")
//        #endif
//    }
}
