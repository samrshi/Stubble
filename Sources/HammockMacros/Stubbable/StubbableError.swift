//
//  File.swift
//  Hammock
//
//  Created by Samuel Shi on 10/12/24.
//

import SwiftSyntax
import SwiftDiagnostics

struct StubbableDiagnostic: DiagnosticMessage {
  enum ID: String {
    case invalidApplication = "invalid type"
  }
  
  var message: String
  var diagnosticID: MessageID
  var severity: DiagnosticSeverity
  
  init(message: String, diagnosticID: MessageID, severity: DiagnosticSeverity = .error) {
    self.message = message
    self.diagnosticID = diagnosticID
    self.severity = severity
  }
  
  init(message: String, domain: String, id: ID, severity: DiagnosticSeverity = .error) {
    self.message = message
    self.diagnosticID = MessageID(domain: domain, id: id.rawValue)
    self.severity = severity
  }
}



extension DiagnosticsError {
    init<S: SyntaxProtocol>(
        syntax: S,
        message: String,
        domain: String = "Stubbable",
        id: StubbableDiagnostic.ID,
        severity: SwiftDiagnostics.DiagnosticSeverity = .error
    ) {
        self.init(
            diagnostics: [
                Diagnostic(
                    node: Syntax(syntax),
                    message: StubbableDiagnostic(message: message, domain: domain, id: id, severity: severity))
            ]
        )
  }
}
