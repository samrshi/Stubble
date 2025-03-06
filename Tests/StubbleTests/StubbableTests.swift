import MacroTesting
import SwiftSyntaxMacros
import XCTest
@testable import StubbleMacros

final class StubbableTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
            macros: ["Stubbable": StubbableMacro.self]
        ) {
            super.invokeTest()
        }
    }

    func testBasicClass() {
        assertMacro {
            """
            @Stubbable
            class NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        } expansion: {
            """
            class NetworkService {
                @StubbableFunction
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        }
    }
    
    func testPropertyApplied() {
        assertMacro {
            """
            @Stubbable
            class NetworkService {
                var x: Int = 0
            }
            """
        } expansion: {
            """
            class NetworkService {
                @StubbableProperty
                var x: Int = 0
            }
            """
        }
    }
    
    func testSkippedMembers() {
        assertMacro {
            """
            @Stubbable
            class NetworkService {
                let constant: Int = 0
            
                var computed: Int { 2 }
            
                static var staticProp: Int = 1
            
                var missingType = 2
            
                func generic<T>(x: T) {}
            
                func rethrowing() rethrows {}
            
                static func staticFunc() {}
            }
            """
        } expansion: {
            """
            class NetworkService {
                let constant: Int = 0

                var computed: Int { 2 }

                static var staticProp: Int = 1
            
                var missingType = 2

                func generic<T>(x: T) {}

                func rethrowing() rethrows {}

                static func staticFunc() {}
            }
            """
        }
    }

    func testBasicStruct() {
        assertMacro {
            """
            @Stubbable
            struct NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        } expansion: {
            """
            struct NetworkService {
                @StubbableFunction
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        }
    }

    func testBasicActor() {
        assertMacro {
            """
            @Stubbable
            actor NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        } expansion: {
            """
            actor NetworkService {
                @StubbableFunction
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        }
    }

    func testErrorExtension() {
        assertMacro {
            """
            class NetworkService {}

            @Stubbable
            extension NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        } diagnostics: {
            """
            class NetworkService {}

            @Stubbable
            ┬─────────
            ╰─ 🛑 '@Stubbable cannot be applied to extension
            extension NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        }
    }

    func testErrorEnum() {
        assertMacro {
            """
            @Stubbable
            enum NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        } diagnostics: {
            """
            @Stubbable
            ┬─────────
            ╰─ 🛑 '@Stubbable' cannot be applied to enum NetworkService
            enum NetworkService {
                func makeRequest() -> String {
                    return "Production"
                }
            }
            """
        }
    }

    func testErrorProtocol() {
        assertMacro {
            """
            @Stubbable
            protocol NetworkService {
                func makeRequest() -> String
            }
            """
        } diagnostics: {
            """
            @Stubbable
            ┬─────────
            ╰─ 🛑 '@Stubbable' cannot be applied to protocol NetworkService
            protocol NetworkService {
                func makeRequest() -> String
            }
            """
        }
    }
}
