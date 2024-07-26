//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@_spi(Experimental)
extension Test {
  public protocol Observer: Sendable {
    init() async

    func runStarted()
    func runEnded()

    func suiteStarted(_ suite: borrowing Test)
    func suiteEnded(_ suite: borrowing Test)

    func testStarted(_ test: borrowing Test)
    func testEnded(_ test: borrowing Test)

    func testCaseStarted(_ testCase: borrowing Test.Case, in test: borrowing Test)
    func testCaseEnded(_ testCase: borrowing Test.Case, in test: borrowing Test)

    func issueRecorded(_ issue: borrowing Issue, in test: borrowing Test?, testCase: borrowing Test.Case?)
  }
}

extension Test.Observer {
  func runStarted() {}
  func runEnded() {}

  func suiteStarted(_ suite: borrowing Test) {}
  func suiteEnded(_ suite: borrowing Test) {}

  func testStarted(_ test: borrowing Test) {}
  func testEnded(_ test: borrowing Test) {}

  func testCaseStarted(_ testCase: borrowing Test.Case, in test: borrowing Test) {}
  func testCaseEnded(_ testCase: borrowing Test.Case, in test: borrowing Test) {}

  func issueRecorded(_ issue: borrowing Issue, in test: borrowing Test?, testCase: borrowing Test.Case?) {}
}

// MARK: - Macro

@_spi(Experimental)
public protocol __TestObserver: Sendable {
  static var __observers: [any Test.Observer] { get async }
}

@_spi(Experimental)
@attached(extension, conformances: Test.Observer)
public macro Observer() = #externalMacro(module: "TestingMacros", type: "ObserverDeclarationMacro")

// MARK: - Attaching to a configuration

extension Configuration {
  /// A string that appears within all auto-generated types conforming to the
  /// `__TestObserver` protocol.
  private static let _testObserverTypeNameMagic = "__🟠$test_observer__"

  private static var _allObservers: [any Test.Observer] {
    get async {
      await withTaskGroup(of: [any Test.Observer].self) { taskGroup in
        enumerateTypes(withNamesContaining: _testObserverTypeNameMagic) { type, _ in
          if let type = type as? any __TestObserver.Type {
            taskGroup.addTask {
              await type.__observers
            }
          }
        }

        return await taskGroup.reduce(into: [], +=)
      }
    }
  }

  mutating func attachObservers() async {
    let observers = await Self._allObservers
    if observers.isEmpty {
      return
    }

    eventHandler = { [oldEventHandler = eventHandler] event, context in
      switch event.kind {
      case .runStarted:
        for observer in observers {
          observer.runStarted()
        }
      case .runEnded:
        for observer in observers {
          observer.runEnded()
        }
      case .testStarted:
        let test = context.test!
        for observer in observers {
          observer.testStarted(test)
        }
      case .testEnded:
        let test = context.test!
        for observer in observers {
          observer.testEnded(test)
        }
      case .testCaseStarted:
        let test = context.test!
        if test.isParameterized {
          let testCase = context.testCase!
          for observer in observers {
            observer.testCaseStarted(testCase, in: test)
          }
        }
      case .testCaseEnded:
        let test = context.test!
        if test.isParameterized {
          let testCase = context.testCase!
          for observer in observers {
            observer.testCaseEnded(testCase, in: test)
          }
        }
      case let .issueRecorded(issue):
        let test = context.test
        let testCase = test.flatMap { $0.isParameterized ? context.testCase : nil }
        for observer in observers {
          observer.issueRecorded(issue, in: test, testCase: testCase)
        }
      default:
        // Not propagated to the observer (yet.)
        break
      }
      oldEventHandler(event, context)
    }
  }
}
