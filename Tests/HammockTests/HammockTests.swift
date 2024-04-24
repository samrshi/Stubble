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
