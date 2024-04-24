import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum MockMacroError: LocalizedError {
    case notAClass
    case classIsFinal
    
    var errorDescription: String? {
        switch self {
        case .notAClass: "@Mockable can currently only be applied to classes."
        case .classIsFinal: "@Mockable cannot currently be applied to final classes."
        }
    }
}

public struct MockableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Throw error if not applied to class
        guard let base = declaration.as(ClassDeclSyntax.self) else { throw MockMacroError.notAClass }
        
        // Throw an error if applied to a final class
        let classIsFinal = base.modifiers.contains { $0.name.tokenKind == .keyword(.final) }
        guard !classIsFinal else { throw MockMacroError.classIsFinal }
        
        // Generate members
        var mockMembers: [MemberBlockItemSyntax] = []
        
        let baseMembers = base.memberBlock.members
        for member in baseMembers {
            guard let memberItem = member.as(MemberBlockItemSyntax.self) else { continue }
            guard let function = memberItem.decl.as(FunctionDeclSyntax.self) else { continue }
            
            // Build peer closure and adjust spacing
            var peerClosure = try buildPeerClosure(for: function)
            peerClosure.leadingTrivia += .newlines(member == baseMembers.first ? 1 : 2)
            peerClosure.trailingTrivia += .newlines(2)
            
            // Build override method
            let override = try buildOverride(for: function)

            // Append both to mocked members list
            mockMembers.append(peerClosure)
            mockMembers.append(override)
        }
        
        // Generate inheritances
        let mockInheritance = InheritanceClauseSyntax {
            InheritedTypeSyntax(type: IdentifierTypeSyntax(name: base.name))
            
            if let baseInheritances = base.inheritanceClause?.inheritedTypes {
                for type in baseInheritances {
                    type
                }
            }
        }
        
        let mock = ClassDeclSyntax(
            name: TokenSyntax.identifier("Mock"),
            genericParameterClause: base.genericParameterClause,
            inheritanceClause: mockInheritance,
            genericWhereClause: base.genericWhereClause,
            memberBlockBuilder: {
                for member in mockMembers {
                    member
                }
            }
        )
        
        return [mock.as(DeclSyntax.self)!]
    }
}
 
extension MockableMacro {
    private static func buildPeerClosure(for function: FunctionDeclSyntax) throws -> MemberBlockItemSyntax {
        let funcName = function.name.text
        let funcSignature = function.signature
        let funcParams = funcSignature.parameterClause
        let funcReturn = funcSignature.returnClause
        
        let closureParams = funcParams.parameters.map { "\($0.type)" }
        let closureParamsStr = closureParams.joined(separator: ", ")
        let closureReturn = funcReturn.map { "\($0.type.trimmed)" } ?? "Void"
        let closureType = "(" + closureParamsStr + ") -> " + closureReturn
        
        let variableName = "_" + funcName
        let variableType = "(\(closureType))?"

        let closureVariable = try VariableDeclSyntax("var \(raw: variableName): \(raw: variableType) = nil")
        return MemberBlockItemSyntax(decl: closureVariable)
    }
    
    private static func buildOverride(for function: FunctionDeclSyntax) throws -> MemberBlockItemSyntax {
        let peerName = "_" + function.name.text
        
        let overrideModifier = DeclModifierSyntax(name: TokenSyntax.keyword(.override))
        let overrideModifiers = [overrideModifier] + function.modifiers
        
        // (param1: param1, param2: param2, ...)
        let arguments = function.signature.parameterClause.parameters.map { param in
            let paramValueToken = param.secondName ?? param.firstName
            let paramReference = DeclReferenceExprSyntax(baseName: paramValueToken)
            
            let paramLabelToken = param.firstName.trimmed == TokenSyntax.wildcardToken() ? nil : param.firstName
            let closureArgument = LabeledExprSyntax(label: paramLabelToken, colon: TokenSyntax.colonToken(), expression: paramReference)
            return closureArgument
        }
        
        // peer(arg1, arg2, ...)
        let peerReference = DeclReferenceExprSyntax(baseName: "peer")
        let peerCall = FunctionCallExprSyntax(callee: peerReference) {
            for argument in arguments {
                // Remove labels from arguments for closure call
                LabeledExprSyntax(expression: argument.expression)
            }
        }

        // super.func(arg1, arg2, ...)
        let superReference = MemberAccessExprSyntax(base: SuperExprSyntax(), name: function.name)
        let superCall = FunctionCallExprSyntax(callee: superReference) {
            for argument in arguments {
                argument
            }
        }
        
        let ifLetExpr = try IfExprSyntax("if let peer = \(raw: peerName)") {
            peerCall
        } else: {
            superCall
        }
        
        let ifLetStatement = ExpressionStmtSyntax(expression: ifLetExpr)
        
        let overrideDecl = FunctionDeclSyntax(
            attributes: function.attributes,
            modifiers: overrideModifiers,
            name: function.name,
            genericParameterClause: function.genericParameterClause,
            signature: function.signature,
            genericWhereClause: function.genericWhereClause,
            bodyBuilder: {
                CodeBlockItemSyntax(item: .stmt(.init(ifLetStatement)))
            }
        )
        
        return MemberBlockItemSyntax(decl: overrideDecl)
    }
}
