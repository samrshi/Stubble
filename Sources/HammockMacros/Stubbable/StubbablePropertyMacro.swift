import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum StubbablePropertyMacro {
    static func basePropertyName(for variableName: TokenSyntax) -> TokenSyntax {
        return "_\(variableName.trimmed)"
    }

    static func getterName(for variableName: TokenSyntax) -> TokenSyntax {
        return "_get\(raw: variableName.text.capitalized)"
    }

    static func setterName(for variableName: TokenSyntax) -> TokenSyntax {
        return "_set\(raw: variableName.text.capitalized)"
    }

    static func unwrapVariable(
        from declaration: some DeclSyntaxProtocol
    ) throws -> (variableDecl: VariableDeclSyntax, type: TypeSyntax, identifier: TokenSyntax) {
        // TODO: Check context to make sure we're in a class/struct/actor?
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            throw DiagnosticsError(
                syntax: declaration,
                message: "'@StubbableProperty' can only be applied to properties",
                id: .invalidApplication
            )
        }
        
        guard variableDecl.isInstance else {
            throw DiagnosticsError(
                syntax: variableDecl,
                message: "'@StubbableProperty' cannot be applied to static properties.",
                id: .invalidApplication
            )
        }
        
        guard variableDecl.isMutable else {
            let newBindingSpecifier = TokenSyntax("var")
                .with(\.leadingTrivia, variableDecl.bindingSpecifier.leadingTrivia)
                .with(\.trailingTrivia, variableDecl.bindingSpecifier.trailingTrivia)

            let variableDeclWithLet = variableDecl
                .with(\.bindingSpecifier, newBindingSpecifier)

            throw DiagnosticsError(
                syntax: variableDecl,
                message: "'@StubbableProperty' can only be applied to 'var' members.",
                id: .invalidApplication,
                fixIt: FixIt(
                    message: StubbableFixItMessage(message: "'@StubbableProperty' requires 'var'", id: .letNotVar),
                    changes: [.replace(oldNode: Syntax(variableDecl), newNode: Syntax(variableDeclWithLet))]
                )
            )
        }

        guard let type = variableDecl.type else {
            let variableDeclWithType = variableDecl
                .with(\.bindings, PatternBindingListSyntax(variableDecl.bindings.map { originalBinding in
                    let missingTypeSyntax = MissingTypeSyntax(leadingTrivia: .space, placeholder: .identifier("<#Type#>"), trailingTrivia: .space)
                    return originalBinding
                        .with(\.pattern, originalBinding.pattern.trimmed)
                        .with(\.typeAnnotation, TypeAnnotationSyntax(type: missingTypeSyntax))
                }))

            throw DiagnosticsError(
                syntax: variableDecl,
                message: "'@StubbableProperty' requires an explicit type",
                id: .invalidApplication,
                fixIt: FixIt(
                    message: StubbableFixItMessage(message: "'@StubbableProperty' requires an explicit type", id: .missingType),
                    changes: [.replace(oldNode: Syntax(variableDecl), newNode: Syntax(variableDeclWithType))]
                )
            )
        }

        guard let identifier = variableDecl.identifier else {
            throw DiagnosticsError(
                syntax: variableDecl,
                message: "'@StubbableProperty' requires an explicit identifier",
                id: .invalidApplication
            )
        }

        return (variableDecl: variableDecl, type: type, identifier: identifier)
    }

    static func declarationIsValid(_ declaration: some DeclSyntaxProtocol) -> Bool {
        do {
            _ = try unwrapVariable(from: declaration)
            return true
        } catch {
            return false
        }
    }
}

extension StubbablePropertyMacro: PeerMacro {
    private static func basePropertyDecl(for variableDecl: VariableDeclSyntax, variableName: TokenSyntax, type: TypeSyntax) -> DeclSyntax {
        let basePropertyDecl: DeclSyntax = "private var \(basePropertyName(for: variableName)): \(type.trimmed)\(variableDecl.initializer.map { " \($0)" } ?? "")"
        return basePropertyDecl
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let (variableDecl, type, variableName) = try unwrapVariable(from: declaration)

        // TODO: Add parentheses if closure type?
        let basePropertyDecl: DeclSyntax =  basePropertyDecl(for: variableDecl, variableName: variableName, type: type)
        let getterPropertyDecl: DeclSyntax = "var \(getterName(for: variableName)): (() -> \(type.trimmed))? = nil"
        let setterPropertyDecl: DeclSyntax = "var \(setterName(for: variableName)): ((\(type.trimmed)) -> Void)? = nil"
        return [basePropertyDecl, getterPropertyDecl, setterPropertyDecl]
    }
}

extension StubbablePropertyMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let (_, _, variableName) = try unwrapVariable(from: declaration)

        let baseProperty = basePropertyName(for: variableName)
        let getter = getterName(for: variableName)
        let setter = setterName(for: variableName)

        let initAccessor: AccessorDeclSyntax = """
        @storageRestrictions(initializes: _\(variableName))
        init(initialValue) {
            _\(variableName) = initialValue
        }
        """

        let getAccessor: AccessorDeclSyntax = """
        get {
            if let \(getter) {
                return \(getter)()
            } else {
                return \(baseProperty)
            }
        }
        """

        let setAccessor: AccessorDeclSyntax = """
        set {
            if let \(setter) {
                \(setter)(newValue)
            } else {
                \(baseProperty) = newValue
            }
        }
        """

        return [
            initAccessor,
            getAccessor,
            setAccessor,
        ]
    }
}
