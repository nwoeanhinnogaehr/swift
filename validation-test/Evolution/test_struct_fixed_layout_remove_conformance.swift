// RUN: %target-resilience-test
// REQUIRES: executable_test

// Use swift-version 4.
// UNSUPPORTED: swift_test_mode_optimize_none_with_implicit_dynamic

import StdlibUnittest
import struct_fixed_layout_remove_conformance


var StructFixedLayoutRemoveConformanceTest = TestSuite("StructFixedLayoutRemoveConformance")

StructFixedLayoutRemoveConformanceTest.test("RemoveConformance") {
  var t = RemoveConformance()

  do {
    t.x = 10
    t.y = 20
    expectEqual(t.x, 10)
    expectEqual(t.y, 20)
  }
}

#if AFTER
protocol MyPointLike {
  var x: Int { get set }
  var y: Int { get set }
}

protocol MyPoint3DLike {
  var z: Int { get set }
}

extension RemoveConformance : MyPointLike {}
extension RemoveConformance : MyPoint3DLike {}

@inline(never) func workWithMyPointLike<T>(_ t: T) {
  var p = t as! MyPointLike
  p.x = 50
  p.y = 60
  expectEqual(p.x, 50)
  expectEqual(p.y, 60)
}

StructFixedLayoutRemoveConformanceTest.test("MyPointLike") {
  var p: MyPointLike = RemoveConformance()

  do {
    p.x = 50
    p.y = 60
    expectEqual(p.x, 50)
    expectEqual(p.y, 60)
  }

  workWithMyPointLike(p)
}
#endif

runAllTests()

