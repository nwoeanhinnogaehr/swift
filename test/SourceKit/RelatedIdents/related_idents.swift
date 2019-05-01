class C1 {
  init() {}
}

func test1() {
  var x : C1 = C1()
}

extension C1 {}

test1()

import Swift

class C2 {
  lazy var lazy_bar : Int = {
    let x = 0
    return x
  }()
}

class C2<Param> {
	func f(t : Param) -> Param {return t}
}

enum X {
  case first(Int, String)
  case second(Int, String)
  case third(Int, String)
  case fourth(Int, String)
}

switch X.first(2, "") {
  case .first(let x, let y):
    print(y)
    fallthrough
  case .second(let x, _):
    print(x)
  case .third(let x, let y):
    fallthrough
  case .fourth(let x, let y):
    print(y)
    print(x)
    break
}

// RUN: %sourcekitd-test -req=related-idents -pos=6:17 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK1 %s
// CHECK1: START RANGES
// CHECK1-NEXT: 1:7 - 2
// CHECK1-NEXT: 6:11 - 2
// CHECK1-NEXT: 6:16 - 2
// CHECK1-NEXT: 9:11 - 2
// CHECK1-NEXT: END RANGES

// RUN: %sourcekitd-test -req=related-idents -pos=5:9 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK2 %s
// CHECK2: START RANGES
// CHECK2-NEXT: 5:6 - 5
// CHECK2-NEXT: 11:1 - 5
// CHECK2-NEXT: END RANGES

// RUN: %sourcekitd-test -req=related-idents -pos=13:10 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK3 %s
// CHECK3:      START RANGES
// CHECK3-NEXT: END RANGES

// RUN: %sourcekitd-test -req=related-idents -pos=18:12 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK4 %s
// CHECK4:      START RANGES
// CHECK4-NEXT: 17:9 - 1
// CHECK4-NEXT: 18:12 - 1
// CHECK4-NEXT: END RANGES

// RUN: %sourcekitd-test -req=related-idents -pos=22:12 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK5 %s
// CHECK5:      START RANGES
// CHECK5-NEXT: 22:10 - 5
// CHECK5-NEXT: 23:13 - 5
// CHECK5-NEXT: 23:23 - 5
// CHECK5-NEXT: END RANGES

// RUN: %sourcekitd-test -req=related-idents -pos=34:19 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK6 %s
// RUN: %sourcekitd-test -req=related-idents -pos=37:20 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK6 %s
// RUN: %sourcekitd-test -req=related-idents -pos=38:11 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK6 %s
// CHECK6:      START RANGES
// CHECK6-NEXT: 34:19 - 1
// CHECK6-NEXT: 37:20 - 1
// CHECK6-NEXT: 38:11 - 1
// CHECK6-NEXT: END RANGES

// RUN: %sourcekitd-test -req=related-idents -pos=34:26 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK7 %s
// RUN: %sourcekitd-test -req=related-idents -pos=35:11 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK7 %s
// CHECK7:      START RANGES
// CHECK7-NEXT: 34:26 - 1
// CHECK7-NEXT: 35:11 - 1
// CHECK7-NEXT: END RANGES

// RUN: %sourcekitd-test -req=related-idents -pos=39:26 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK8 %s
// RUN: %sourcekitd-test -req=related-idents -pos=41:27 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK8 %s
// RUN: %sourcekitd-test -req=related-idents -pos=42:11 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK8 %s
// CHECK8:      START RANGES
// CHECK8-NEXT: 39:26 - 1
// CHECK8-NEXT: 41:27 - 1
// CHECK8-NEXT: 42:11 - 1
// CHECK8-NEXT: END RANGES

// RUN: %sourcekitd-test -req=related-idents -pos=39:19 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK9 %s
// RUN: %sourcekitd-test -req=related-idents -pos=41:20 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK9 %s
// RUN: %sourcekitd-test -req=related-idents -pos=43:11 %s -- -module-name related_idents %s | %FileCheck -check-prefix=CHECK9 %s
// CHECK9:      START RANGES
// CHECK9-NEXT: 39:19 - 1
// CHECK9-NEXT: 41:20 - 1
// CHECK9-NEXT: 43:11 - 1
// CHECK9-NEXT: END RANGES
