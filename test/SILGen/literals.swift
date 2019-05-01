// RUN: %target-swift-emit-silgen %s | %FileCheck %s

func takesOptionalFunction(_: (() -> ())?) {}

struct CustomNull : ExpressibleByNilLiteral {
  init(nilLiteral: ()) {}
}

func takesANull(_: CustomNull) {}

// CHECK-LABEL: sil hidden [ossa] @$s8literals4testyyF : $@convention(thin) () -> ()
func test() {
  // CHECK: [[NIL:%.*]] = enum $Optional<@callee_guaranteed () -> ()>, #Optional.none!enumelt
  // CHECK: [[FN:%.*]] = function_ref @$s8literals21takesOptionalFunctionyyyycSgF
  // CHECK: apply [[FN]]([[NIL]])
  _ = takesOptionalFunction(nil)

  // CHECK: [[METATYPE:%.*]] = metatype $@thin CustomNull.Type
  // CHECK: [[NIL_FN:%.*]] = function_ref @$s8literals10CustomNullV10nilLiteralACyt_tcfC
  // CHECK: [[NIL:%.*]] = apply [[NIL_FN]]([[METATYPE]])
  // CHECK: [[FN:%.*]] = function_ref @$s8literals10takesANullyyAA10CustomNullVF
  // CHECK: apply [[FN]]([[NIL]])
  _ = takesANull(nil)
}

class CustomStringClass : ExpressibleByStringLiteral {
  required init(stringLiteral value: String) {}
  required init(extendedGraphemeClusterLiteral value: String) {}
  required init(unicodeScalarLiteral value: String) {}
}

class CustomStringSubclass : CustomStringClass {}

// CHECK-LABEL: sil hidden [ossa] @$s8literals27returnsCustomStringSubclassAA0cdE0CyF : $@convention(thin) () -> @owned CustomStringSubclass
// CHECK: [[METATYPE:%.*]] = metatype $@thick CustomStringSubclass.Type
// CHECK: [[UPCAST:%.*]] = upcast [[METATYPE]] : $@thick CustomStringSubclass.Type to $@thick CustomStringClass.Type
// CHECK: [[CTOR:%.*]] = class_method [[UPCAST]] : $@thick CustomStringClass.Type, #CustomStringClass.init!allocator.1 : (CustomStringClass.Type) -> (String) -> CustomStringClass, $@convention(method) (@owned String, @thick CustomStringClass.Type) -> @owned CustomStringClass
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]({{%.*}}, [[UPCAST]])
// CHECK: [[DOWNCAST:%.*]] = unchecked_ref_cast [[RESULT]] : $CustomStringClass to $CustomStringSubclass
// CHECK: return [[DOWNCAST]]
func returnsCustomStringSubclass() -> CustomStringSubclass {
  return "hello world"
}

class TakesArrayLiteral<Element> : ExpressibleByArrayLiteral {
  required init(arrayLiteral elements: Element...) {}
}

// CHECK-LABEL: sil hidden [ossa] @$s8literals18returnsCustomArrayAA05TakesD7LiteralCySiGyF : $@convention(thin) () -> @owned TakesArrayLiteral<Int>
// CHECK: [[TMP:%.*]] = apply %2(%0, %1) : $@convention(method) (Builtin.IntLiteral, @thin Int.Type) -> Int
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 2
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<Int>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]
// CHECK: store [[TMP:%.*]] to [trivial] [[POINTER]]
// CHECK: [[IDX1:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[POINTER1:%.*]] = index_addr [[POINTER]] : $*Int, [[IDX1]] : $Builtin.Word
// CHECK: store [[TMP:%.*]] to [trivial] [[POINTER1]]
// CHECK: [[METATYPE:%.*]] = metatype $@thick TakesArrayLiteral<Int>.Type
// CHECK: [[CTOR:%.*]] = class_method %15 : $@thick TakesArrayLiteral<Int>.Type, #TakesArrayLiteral.init!allocator.1 : <Element> (TakesArrayLiteral<Element>.Type) -> (Element...) -> TakesArrayLiteral<Element>, $@convention(method)
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]<Int>([[ARR]], [[METATYPE]])
// CHECK: return [[RESULT]]
func returnsCustomArray() -> TakesArrayLiteral<Int> {
  // Use temporary to simplify generated_sil
  let tmp = 77
  return [tmp, tmp]
}

class Klass {}

// CHECK-LABEL: sil hidden [ossa] @$s8literals24returnsClassElementArrayAA05TakesE7LiteralCyAA5KlassCGyF : $@convention(thin) () -> @owned TakesArrayLiteral<Klass>
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<Klass>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]
// CHECK: [[KLASS_METATYPE:%.*]] = metatype $@thick Klass.Type
// CHECK: [[CTOR:%.*]] = function_ref @$s8literals5KlassCACycfC : $@convention(method) (@thick Klass.Type) -> @owned Klass
// CHECK: [[TMP:%.*]] = apply [[CTOR]]([[KLASS_METATYPE]]) : $@convention(method) (@thick Klass.Type) -> @owned Klass
// CHECK: store [[TMP]] to [init] [[POINTER]]
// CHECK: [[METATYPE:%.*]] = metatype $@thick TakesArrayLiteral<Klass>.Type
// CHECK: [[CTOR:%.*]] = class_method [[METATYPE]] : $@thick TakesArrayLiteral<Klass>.Type, #TakesArrayLiteral.init!allocator.1 : <Element> (TakesArrayLiteral<Element>.Type) -> (Element...) -> TakesArrayLiteral<Element>, $@convention(method)
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]<Klass>([[ARR]], [[METATYPE]])
// CHECK: return [[RESULT]]
func returnsClassElementArray() -> TakesArrayLiteral<Klass> {
  return [Klass()]
}

struct Foo<T> {
  var t: T
}

// CHECK-LABEL: sil hidden [ossa] @$s8literals30returnsAddressOnlyElementArray1tAA05TakesF7LiteralCyAA3FooVyxGGAH_tlF : $@convention(thin) <T> (@in_guaranteed Foo<T>) -> @owned TakesArrayLiteral<Foo<T>>
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<Foo<T>>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]
// CHECK: copy_addr %0 to [initialization] [[POINTER]] : $*Foo<T>
// CHECK: [[METATYPE:%.*]] = metatype $@thick TakesArrayLiteral<Foo<T>>.Type
// CHECK: [[CTOR:%.*]] = class_method [[METATYPE]] : $@thick TakesArrayLiteral<Foo<T>>.Type, #TakesArrayLiteral.init!allocator.1 : <Element> (TakesArrayLiteral<Element>.Type) -> (Element...) -> TakesArrayLiteral<Element>, $@convention(method)
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]<Foo<T>>([[ARR]], [[METATYPE]])
// CHECK: return [[RESULT]]
func returnsAddressOnlyElementArray<T>(t: Foo<T>) -> TakesArrayLiteral<Foo<T>> {
  return [t]
}

// CHECK-LABEL: sil hidden [ossa] @$s8literals3FooV20returnsArrayFromSelfAA05TakesD7LiteralCyACyxGGyF : $@convention(method) <T> (@in_guaranteed Foo<T>) -> @owned TakesArrayLiteral<Foo<T>>
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<Foo<T>>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]
// CHECK: copy_addr %0 to [initialization] [[POINTER]] : $*Foo<T>
// CHECK: [[METATYPE:%.*]] = metatype $@thick TakesArrayLiteral<Foo<T>>.Type
// CHECK: [[CTOR:%.*]] = class_method [[METATYPE]] : $@thick TakesArrayLiteral<Foo<T>>.Type, #TakesArrayLiteral.init!allocator.1 : <Element> (TakesArrayLiteral<Element>.Type) -> (Element...) -> TakesArrayLiteral<Element>, $@convention(method)
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]<Foo<T>>([[ARR]], [[METATYPE]])
// CHECK: return [[RESULT]]
extension Foo {
  func returnsArrayFromSelf() -> TakesArrayLiteral<Foo<T>> {
    return [self]
  }
}

// CHECK-LABEL: sil hidden [ossa] @$s8literals3FooV28returnsArrayFromMutatingSelfAA05TakesD7LiteralCyACyxGGyF : $@convention(method) <T> (@inout Foo<T>) -> @owned TakesArrayLiteral<Foo<T>>
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<Foo<T>>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]
// CHECK: [[ACCESS:%.*]] = begin_access [read] [unknown] %0 : $*Foo<T>
// CHECK: copy_addr [[ACCESS]] to [initialization] [[POINTER]] : $*Foo<T>
// CHECK: end_access [[ACCESS]] : $*Foo<T>
// CHECK: [[METATYPE:%.*]] = metatype $@thick TakesArrayLiteral<Foo<T>>.Type
// CHECK: [[CTOR:%.*]] = class_method [[METATYPE]] : $@thick TakesArrayLiteral<Foo<T>>.Type, #TakesArrayLiteral.init!allocator.1 : <Element> (TakesArrayLiteral<Element>.Type) -> (Element...) -> TakesArrayLiteral<Element>, $@convention(method)
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]<Foo<T>>([[ARR]], [[METATYPE]])
// CHECK: return [[RESULT]]
extension Foo {
  mutating func returnsArrayFromMutatingSelf() -> TakesArrayLiteral<Foo<T>> {
    return [self]
  }
}

struct Foo2 {
  var k: Klass
}

// CHECK-LABEL: sil hidden [ossa] @$s8literals23returnsNonTrivialStructAA17TakesArrayLiteralCyAA4Foo2VGyF : $@convention(thin) () -> @owned TakesArrayLiteral<Foo2>
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<Foo2>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]
// CHECK: [[METATYPE_FOO2:%.*]] = metatype $@thin Foo2.Type
// CHECK: [[METATYPE_KLASS:%.*]] = metatype $@thick Klass.Type
// CHECK: [[CTOR:%.*]] = function_ref @$s8literals5KlassCACycfC : $@convention(method) (@thick Klass.Type) -> @owned Klass
// CHECK: [[K:%.*]] = apply [[CTOR]]([[METATYPE_KLASS]]) : $@convention(method) (@thick Klass.Type) -> @owned Klass
// CHECK: [[CTOR:%.*]] = function_ref @$s8literals4Foo2V1kAcA5KlassC_tcfC : $@convention(method) (@owned Klass, @thin Foo2.Type) -> @owned Foo2
// CHECK: [[TMP:%.*]] = apply [[CTOR]]([[K]], [[METATYPE_FOO2]]) : $@convention(method) (@owned Klass, @thin Foo2.Type) -> @owned Foo2
// store [[TMP]] to [init] [[POINTER]] : $*Foo2
// CHECK: [[METATYPE:%.*]] = metatype $@thick TakesArrayLiteral<Foo2>.Type
// CHECK: [[CTOR:%.*]] = class_method [[METATYPE]] : $@thick TakesArrayLiteral<Foo2>.Type, #TakesArrayLiteral.init!allocator.1 : <Element> (TakesArrayLiteral<Element>.Type) -> (Element...) -> TakesArrayLiteral<Element>, $@convention(method)
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]<Foo2>([[ARR]], [[METATYPE]])
// CHECK: return [[RESULT]]
func returnsNonTrivialStruct() -> TakesArrayLiteral<Foo2> {
  return [Foo2(k: Klass())]
}

// CHECK-LABEL: sil hidden [ossa] @$s8literals16NestedLValuePathV11wrapInArrayyyF : $@convention(method) (@inout NestedLValuePath) -> ()
// CHECK: [[METATYPE_NESTED:%.*]] = metatype $@thin NestedLValuePath.Type
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<NestedLValuePath>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]

// CHECK: [[ACCESS:%.*]] = begin_access [modify] [unknown] %0 : $*NestedLValuePath
// CHECK: [[OTHER_FN:%.*]] = function_ref @$s8literals16NestedLValuePathV21otherMutatingFunctionACyF : $@convention(method) (@inout NestedLValuePath) -> @owned NestedLValuePath
// CHECK: [[TMP:%.*]] = apply [[OTHER_FN]]([[ACCESS]]) : $@convention(method) (@inout NestedLValuePath) -> @owned NestedLValuePath
// CHECK: end_access [[ACCESS]] : $*NestedLValuePath
// CHECK: store [[TMP]] to [init] [[POINTER]] : $*NestedLValuePath
// CHECK: [[METATYPE:%.*]] = metatype $@thick TakesArrayLiteral<NestedLValuePath>.Type
// CHECK: [[CTOR:%.*]] = class_method [[METATYPE]] : $@thick TakesArrayLiteral<NestedLValuePath>.Type, #TakesArrayLiteral.init!allocator.1 : <Element> (TakesArrayLiteral<Element>.Type) -> (Element...) -> TakesArrayLiteral<Element>, $@convention(method)
// CHECK: [[ARR_RESULT:%.*]] = apply [[CTOR]]<NestedLValuePath>([[ARR]], [[METATYPE]])
// CHECK: [[CTOR:%.*]] = function_ref @$s8literals16NestedLValuePathV3arrAcA17TakesArrayLiteralCyACG_tcfC : $@convention(method) (@owned TakesArrayLiteral<NestedLValuePath>, @thin NestedLValuePath.Type) -> @owned NestedLValuePath // user: %18
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]([[ARR_RESULT]], [[METATYPE_NESTED]]) : $@convention(method) (@owned TakesArrayLiteral<NestedLValuePath>, @thin NestedLValuePath.Type) -> @owned NestedLValuePath
// CHECK: [[ACCESS:%.*]] = begin_access [modify] [unknown] %0 : $*NestedLValuePath
// CHECK: assign [[RESULT]] to [[ACCESS]] : $*NestedLValuePath
// CHECK: end_access [[ACCESS]] : $*NestedLValuePath
// CHECK: [[VOID:%.*]] = tuple ()
// CHECK: return [[VOID]] : $()
struct NestedLValuePath {
  var arr: TakesArrayLiteral<NestedLValuePath>

  mutating func wrapInArray() {
    self = NestedLValuePath(arr: [self.otherMutatingFunction()])
  }

  mutating func otherMutatingFunction() -> NestedLValuePath {
    return self
  }
}

protocol WrapsSelfInArray {}

// CHECK-LABEL: sil hidden [ossa] @$s8literals16WrapsSelfInArrayPAAE04wrapdE0AA05TakesE7LiteralCyAaB_pGyF : $@convention(method) <Self where Self : WrapsSelfInArray> (@inout Self) -> @owned TakesArrayLiteral<WrapsSelfInArray>
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<WrapsSelfInArray>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]
// CHECK: [[ACCESS:%.*]] = begin_access [read] [unknown] %0 : $*Self
// CHECK: [[EXISTENTIAL:%.*]] = init_existential_addr [[POINTER]] : $*WrapsSelfInArray, $Self
// CHECK: copy_addr [[ACCESS]] to [initialization] [[EXISTENTIAL]] : $*Self
// CHECK: end_access [[ACCESS]] : $*Self
// CHECK: [[METATYPE:%.*]] = metatype $@thick TakesArrayLiteral<WrapsSelfInArray>.Type
// CHECK: [[CTOR:%.*]] = class_method [[METATYPE]] : $@thick TakesArrayLiteral<WrapsSelfInArray>.Type, #TakesArrayLiteral.init!allocator.1 : <Element> (TakesArrayLiteral<Element>.Type) -> (Element...) -> TakesArrayLiteral<Element>, $@convention(method)
// CHECK: [[RESULT:%.*]] = apply [[CTOR]]<WrapsSelfInArray>([[ARR]], [[METATYPE]])
// CHECK: return [[RESULT]]
extension WrapsSelfInArray {
  mutating func wrapInArray() -> TakesArrayLiteral<WrapsSelfInArray> {
    return [self]
  }
}

protocol FooProtocol {
  init()
}

func makeThrowing<T : FooProtocol>() throws -> T { return T() }
func makeBasic<T : FooProtocol>() -> T { return T() }

// CHECK-LABEL: sil hidden [ossa] @$s8literals15throwingElementSayxGyKAA11FooProtocolRzlF : $@convention(thin) <T where T : FooProtocol> () -> (@owned Array<T>, @error Error)
// CHECK: [[ARRAY_LENGTH:%.*]] = integer_literal $Builtin.Word, 2
// CHECK: [[ALLOCATE_VARARGS:%.*]] = function_ref @$ss27_allocateUninitializedArrayySayxG_BptBwlF
// CHECK: [[ARR_TMP:%.*]] = apply [[ALLOCATE_VARARGS]]<T>([[ARRAY_LENGTH]])
// CHECK: ([[ARR:%.*]], [[ADDRESS:%.*]]) = destructure_tuple [[ARR_TMP]]
// CHECK: [[POINTER:%.*]] = pointer_to_address [[ADDRESS]]
// CHECK: [[FN:%.*]] = function_ref @$s8literals9makeBasicxyAA11FooProtocolRzlF : $@convention(thin)
// CHECK: [[TMP:%.*]] = apply [[FN]]<T>([[POINTER]])
// CHECK: [[IDX:%.*]] = integer_literal $Builtin.Word, 1
// CHECK: [[POINTER1:%.*]] = index_addr [[POINTER]] : $*T, [[IDX]] : $Builtin.Word
// CHECK: [[FN:%.*]] = function_ref @$s8literals12makeThrowingxyKAA11FooProtocolRzlF : $@convention(thin)
// CHECK: try_apply [[FN]]<T>([[POINTER1]]) : {{.*}} normal bb1, error bb2

// CHECK: bb1([[TMP:%.*]] : $()):
// CHECK: return [[ARR]]

// CHECK: bb2([[ERR:%.*]] : @owned $Error):
// CHECK: destroy_addr [[POINTER]] : $*T
// CHECK: [[DEALLOC:%.*]] = function_ref @$ss29_deallocateUninitializedArrayyySayxGnlF
// CHECK: [[TMP:%.*]] = apply [[DEALLOC]]<T>([[ARR]])
// CHECK: throw [[ERR]] : $Error
func throwingElement<T : FooProtocol>() throws -> [T] {
  return try [makeBasic(), makeThrowing()]
}
