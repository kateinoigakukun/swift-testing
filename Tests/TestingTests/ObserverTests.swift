//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//

@testable @_spi(Experimental) import Testing

@Observer struct ExampleObserver {
  func issueRecorded(_ issue: borrowing Issue, in test: borrowing Test?, testCase: borrowing Test.Case?) {
    let test = copy test
    let testName = String(describingForTest: test?.displayName ?? test?.name)
    print("Oh no! An issue occurred in \(testName): \(issue)")
  }

  func runEnded() {
    print("Bye bye!")
  }
}
