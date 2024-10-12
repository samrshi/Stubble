import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

struct StubbableMacro: MemberAttributeMacro {
    static public func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        try ensureCorrectApplication(macroSyntax: node, declaration: declaration)
        return [AttributeSyntax("@StubbableMember")]
    }
}

extension StubbableMacro {
    private static func ensureCorrectApplication(macroSyntax: AttributeSyntax, declaration: some DeclGroupSyntax) throws {
        if declaration.is(ExtensionDeclSyntax.self) {
            throw DiagnosticsError(syntax: macroSyntax, message: "'@Stubbable cannot be applied to extension", id: .invalidApplication)
        }
        
        guard let identified = declaration.asProtocol(NamedDeclSyntax.self) else {
            throw DiagnosticsError(syntax: macroSyntax, message: "'@Stubbable' must be applied to a named type", id: .invalidApplication)
        }
        
        let stubbableTypeName = identified.name.trimmed
        
        
        if declaration.is(EnumDeclSyntax.self) {
            throw DiagnosticsError(syntax: macroSyntax, message: "'@Stubbable' cannot be applied to enum \(stubbableTypeName)", id: .invalidApplication)
        }
        
        if declaration.is(ProtocolDeclSyntax.self) {
            throw DiagnosticsError(syntax: macroSyntax, message: "'@Stubbable' cannot be applied to protocol \(stubbableTypeName)", id: .invalidApplication)
        }
    }
}
