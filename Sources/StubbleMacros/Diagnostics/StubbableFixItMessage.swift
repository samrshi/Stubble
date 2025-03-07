import SwiftDiagnostics

struct StubbableFixItMessage: FixItMessage {
    enum ID: String {
        case missingType = "missing type"
        case letNotVar = "let not var"
    }

    let fixItID: MessageID
    let message: String

    init(
        message: String,
        domain: String = "Stubbable",
        id: ID
    ) {
        self.fixItID = MessageID(domain: domain, id: id.rawValue)
        self.message = message
    }
}
