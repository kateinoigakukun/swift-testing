//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

public import SwiftSyntax
public import SwiftSyntaxMacros
import SwiftParser

/// A type describing the expansion of the `@Observer` attribute macro.
///
/// This type is used to implement the `@Observer` attribute macro. Do not use
/// it directly.
public struct ObserverDeclarationMacro: ExtensionMacro, Sendable {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let typeName = declaration.type.trimmed
    let enumName = context.makeUniqueName("__🟠$test_observer__\(typeName)")

    // Check if the lexical context is appropriate for an observer (NOTE: may
    // need slightly different semantics here than for suites and tests.)
    var diagnostics = [DiagnosticMessage]()
    diagnostics += diagnoseIssuesWithLexicalContext(context.lexicalContext, containing: declaration, attribute: node)
    diagnostics += diagnoseIssuesWithLexicalContext(declaration, containing: declaration, attribute: node)
    if !diagnostics.isEmpty {
      context.diagnose(diagnostics)
      return []
    }

    let alreadyConformsToObserver = protocols.contains { $0.isNamed("Observer", inModuleNamed: "Testing") }
    let conformanceClause = if alreadyConformsToObserver {
      ""
    } else {
      ": Testing.Test.Observer"
    }

    let extensionDecl: DeclSyntax = """
      extension \(typeName) \(raw: conformanceClause) {
        @available(*, deprecated, message: "This type is an implementation detail of the testing library. Do not use it directly.")
        enum \(enumName): Testing.__TestObserver {
          static var __observers: [any Testing.Test.Observer] {
            get async {[
              await (\(typeName)(), Testing.__requiringAwait).0
            ]}
          }
        }
      }
      """

    return [extensionDecl.cast(ExtensionDeclSyntax.self)]
  }
}
