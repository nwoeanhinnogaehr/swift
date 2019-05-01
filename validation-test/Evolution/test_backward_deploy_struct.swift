// RUN: %target-resilience-test --backward-deployment
// REQUIRES: executable_test

// Use swift-version 4.
// UNSUPPORTED: swift_test_mode_optimize_none_with_implicit_dynamic

import StdlibUnittest
import backward_deploy_struct


var BackwardDeployStructTest = TestSuite("BackwardDeployStruct")

BackwardDeployStructTest.test("ResilientStruct") {
  if getVersion() == 1 {
    var s = ResilientStruct()

    s.fn(s.storedProp)
    s.storedProp = 1
    s.storedProp += 1

    s.fn(s.computedProp)
    s.computedProp = 1
    s.computedProp += 1

    s.fn(s[0])
    s[0] = 1
    s[0] += 1
  }
}

BackwardDeployStructTest.test("FixedLayoutStruct") {
  if getVersion() == 1 {
    var s = FixedLayoutStruct()

    s.fn(s.storedProp)
    s.storedProp = 1
    s.storedProp += 1

    s.fn(s.computedProp)
    s.computedProp = 1
    s.computedProp += 1

    s.fn(s[0])
    s[0] = 1
    s[0] += 1
  }
}

runAllTests()
