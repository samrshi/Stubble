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
        
        guard variableDecl.bindingSpecifier.text == "var" else {
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
    private static func basePropertyDecl(for variableDecl: VariableDeclSyntax) -> VariableDeclSyntax {
        let newBindings = PatternBindingListSyntax(variableDecl.bindings.map {
            guard let identifier = $0.pattern.as(IdentifierPatternSyntax.self)?.identifier else { return $0 }
            let newIdentifierPattern = IdentifierPatternSyntax(identifier: basePropertyName(for: identifier))
            let newPattern = PatternSyntax(fromProtocol: newIdentifierPattern)
            return $0.with(\.pattern, newPattern)
        })

        let newAttributes = variableDecl.attributes.filter { attribute in
            switch attribute {
            case .attribute(let attributeSyntax):
                return attributeSyntax.attributeName.as(IdentifierTypeSyntax.self)?.name.text != "StubbableProperty"
            case .ifConfigDecl:
                return true
            }
        }

        return VariableDeclSyntax(
            leadingTrivia: variableDecl.leadingTrivia,
            attributes: newAttributes,
            modifiers: variableDecl.modifiers, // TODO: Check this for access modifiers
            bindingSpecifier: variableDecl.bindingSpecifier,
            bindings: newBindings,
            trailingTrivia: variableDecl.trailingTrivia
        )
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let (variableDecl, type, variableName) = try unwrapVariable(from: declaration)

        // TODO: Add parentheses if closure type?
        let basePropertyDecl: DeclSyntax = DeclSyntax(fromProtocol: basePropertyDecl(for: variableDecl))
        let getterPropertyDecl: DeclSyntax = "var \(getterName(for: variableName)): (() -> \(type.trimmed))? = nil"
        let setterPropertyDecl: DeclSyntax = "var \(setterName(for: variableName)): ((inout \(type.trimmed), \(type.trimmed)) -> Void)? = nil"
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
                \(setter)(&\(baseProperty), newValue)
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
