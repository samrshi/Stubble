import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct HammockPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        MockableMacro.self,
        StubbableMacro.self,
        StubbableFunctionMacro.self,
        StubbablePropertyMacro.self,
    ]
}
