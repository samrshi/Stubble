import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StubbableFunctionMacro {}

extension StubbableFunctionMacro {
    private static func peerName(for function: FunctionDeclSyntax) -> String {
        return "_" + function.name.text
    }
    
    private static func ensureFunction(
        for declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax
    ) throws -> (function: FunctionDeclSyntax, body: CodeBlockItemListSyntax) {
        guard
            let function = declaration.as(FunctionDeclSyntax.self),
            let body = function.body?.statements
        else {
            throw DiagnosticsError(
                syntax: declaration,
                message: "'@StubbableFunction' can only be applied to functions",
                id: .invalidApplication)
        }
        
        if let genericParameterClause = function.genericParameterClause {
            throw DiagnosticsError(
                syntax: genericParameterClause,
                message: "'@StubbableFunction' currently does not support generic functions",
                id: .invalidApplication
            )
        }
        
        return (function, body)
    }
    
    private static func functionBodyIsSingleExpr(body: CodeBlockItemListSyntax) -> Bool {
        if body.count == 1,
           let firstItem = body.first,
           case .expr = firstItem.item
        {
            return true
        } else {
            return false
        }
    }

    private static func functionIsNonVoid(function: FunctionDeclSyntax) -> Bool {
        // Return false if function has return clause
        guard let returnClause = function.signature.returnClause else {
            return false
        }
        
        // Return false if return type is 'Void' or 'Never'
        if let identifierType = returnClause.type.as(IdentifierTypeSyntax.self),
           identifierType.name.text == "Void" || identifierType.name.text == "Never" {
            return false
        }
        
        // Return false if return type is 'Swift.Void' or 'Swift.Never'
        if let memberType = returnClause.type.as(MemberTypeSyntax.self),
           let baseType = memberType.baseType.as(IdentifierTypeSyntax.self),
           baseType.name.text == "Swift",
           memberType.name.text == "Void" || memberType.name.text == "Never" {
            return false
        }
        
        // Return false if return clause is '-> ()'
        if let tupleType = returnClause.type.as(TupleTypeSyntax.self),
           tupleType.elements.isEmpty {
            return false
        }
        
        // Return false if return clause is '-> (Void)'
        if let tupleType = returnClause.type.as(TupleTypeSyntax.self),
           tupleType.elements.count == 1,
           let firstType = tupleType.elements.first?.type.as(IdentifierTypeSyntax.self),
           firstType.name.text == "Void" {
            return false
        }
        
        // Return false if return clause is '-> (Swift.Void)'
        if let tupleType = returnClause.type.as(TupleTypeSyntax.self),
           tupleType.elements.count == 1,
           let firstType = tupleType.elements.first?.type.as(MemberTypeSyntax.self),
           let baseType = firstType.baseType.as(IdentifierTypeSyntax.self),
           baseType.name.text == "Swift", firstType.name.text == "Void" {
            return false
        }

        // Function does have omitted return
        return true
    }
}

extension StubbableFunctionMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        let (function, originalBody) = try ensureFunction(for: declaration)
        return try buildNewBody(for: function, originalBody: originalBody)
    }
    
    private static func buildNewBody(
        for function: FunctionDeclSyntax,
        originalBody: CodeBlockItemListSyntax
    ) throws -> [CodeBlockItemSyntax] {
        // (param1: param1, param2: param2, ...)
        // TODO: Remove this section
        let arguments = function.signature.parameterClause.parameters.map { param in
            let paramValueToken = param.secondName ?? param.firstName
            let paramReference = DeclReferenceExprSyntax(baseName: paramValueToken)
            
            let paramIsWildcard = param.firstName.tokenKind == .wildcard
            let paramLabelToken = paramIsWildcard ? nil : param.firstName
            let colonToken = paramIsWildcard ? nil : TokenSyntax.colonToken()
            let closureArgument = LabeledExprSyntax(label: paramLabelToken, colon: colonToken, expression: paramReference)
            return closureArgument
        }
        
        // peer(arg1, arg2, ...)
        let peerReference = DeclReferenceExprSyntax(baseName: .identifier(peerName(for: function)))
        let peerCall = FunctionCallExprSyntax(callee: peerReference) {
            for argument in arguments {
                // Remove labels from arguments for closure call
                LabeledExprSyntax(expression: argument.expression)
            }
        }
        
        // Add try and/or await if necessary
        let funcIsAsync = function.signature.effectSpecifiers?.asyncSpecifier != nil
        let funcThrows = function.signature.effectSpecifiers?.throwsClause != nil
        
        let tryAwaitPeerCall: ExprSyntaxProtocol = switch (funcThrows, funcIsAsync) {
        case (true, true): TryExprSyntax(tryKeyword: .keyword(.try, trailingTrivia: .space), expression: AwaitExprSyntax(awaitKeyword: .keyword(.await, trailingTrivia: .space), expression: peerCall))
        case (true, false): TryExprSyntax(tryKeyword: .keyword(.try, trailingTrivia: .space), expression: peerCall)
        case (false, true): AwaitExprSyntax(awaitKeyword: .keyword(.await, trailingTrivia: .space), expression: peerCall)
        case (false, false): peerCall
        }
        
        // Check if function has omitted return
        let isNonVoid = functionIsNonVoid(function: function)
        let isSingleExpr = functionBodyIsSingleExpr(body: originalBody)
        let hasOmittedReturn = isNonVoid && isSingleExpr
        
        // Build if let expression
        let ifLetExpr = try IfExprSyntax("if let \(raw: peerName(for: function))") {
            isNonVoid ? "return \(tryAwaitPeerCall)" : "\(tryAwaitPeerCall)"
        } else: {
            hasOmittedReturn ? "return \(originalBody.trimmed)" : originalBody
        }
        
        // Return result
        let newBodyExpr = ExprSyntax(ifLetExpr)
        let newBody = CodeBlockItemSyntax(item: .expr(newBodyExpr))
        return [newBody]
    }
}

extension StubbableFunctionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            throw DiagnosticsError(
                syntax: node,
                message: "'@StubbableFunction' can only be applied to functions",
                id: .invalidApplication)
        }
        
        let peerClosureDecl = try buildPeerClosureDecl(for: function)
        return [DeclSyntax(peerClosureDecl)]
    }
    
    private static func buildPeerClosureDecl(for function: FunctionDeclSyntax) throws -> VariableDeclSyntax {
        let funcParams = function.signature.parameterClause
        let funcReturn = function.signature.returnClause
        let funcIsAsync = function.signature.effectSpecifiers?.asyncSpecifier != nil
        let funcThrows = function.signature.effectSpecifiers?.throwsClause != nil
        
        let closureParams = funcParams.parameters.map {
            if $0.ellipsis != nil {
                // Variadic parameters turn into arrays
                "[\($0.type)]"
            } else {
                // Everything else has exact same type as original
                "\($0.type)"
            }
        }
        let closureParamsStr = closureParams.joined(separator: ", ")
        let closureAsyncKeyword = funcIsAsync ? "async " : ""
        let closureThrowsKeyword = funcThrows ? "throws " : ""
        let closureReturn = funcReturn.map { "\($0.type.trimmed)" } ?? "Void"
        let closureType = "(" + closureParamsStr + ") \(closureAsyncKeyword)\(closureThrowsKeyword)-> " + closureReturn
        
        let variableName = peerName(for: function)
        let variableType = "(\(closureType))?"

        return try VariableDeclSyntax("var \(raw: variableName): \(raw: variableType) = nil")
    }
}
