// RUN: %target-typecheck-verify-swift -swift-version 5

// ---------------------------------------------------------------------------
// Property delegate type definitions
// ---------------------------------------------------------------------------
@_propertyDelegate
struct Wrapper<T> {
  var value: T
}

@_propertyDelegate
struct WrapperWithInitialValue<T> {
  var value: T

  init(initialValue: T) {
    self.value = initialValue
  }
}

@_propertyDelegate
struct WrapperAcceptingAutoclosure<T> {
  private let fn: () -> T

  var value: T {
    return fn()
  }

  init(initialValue fn: @autoclosure @escaping () -> T) {
    self.fn = fn
  }

  init(body fn: @escaping () -> T) {
    self.fn = fn
  }
}

@_propertyDelegate
struct MissingValue<T> { }
// expected-error@-1{{property delegate type 'MissingValue' does not contain a non-static property named 'value'}}

@_propertyDelegate
struct StaticValue {
  static var value: Int = 17
}
// expected-error@-3{{property delegate type 'StaticValue' does not contain a non-static property named 'value'}}


// expected-error@+1{{'@_propertyDelegate' attribute cannot be applied to this declaration}}
@_propertyDelegate
protocol CannotBeADelegate {
  associatedtype Value
  var value: Value { get set }
}

@_propertyDelegate
struct NonVisibleValueDelegate<Value> {
  private var value: Value // expected-error{{private property 'value' cannot have more restrictive access than its enclosing property delegate type 'NonVisibleValueDelegate' (which is internal)}}
}

@_propertyDelegate
struct NonVisibleInitDelegate<Value> {
  var value: Value

  private init(initialValue: Value) { // expected-error{{private initializer 'init(initialValue:)' cannot have more restrictive access than its enclosing property delegate type 'NonVisibleInitDelegate' (which is internal)}}
    self.value = initialValue
  }
}

@_propertyDelegate
struct InitialValueTypeMismatch<Value> {
  var value: Value // expected-note{{'value' declared here}}

  init(initialValue: Value?) { // expected-error{{'init(initialValue:)' parameter type ('Value?') must be the same as its 'value' property type ('Value') or an @autoclosure thereof}}
    self.value = initialValue!
  }
}

@_propertyDelegate
struct MultipleInitialValues<Value> { // expected-error{{property delegate type 'MultipleInitialValues' has multiple initial-value initializers}}
  var value: Value? = nil

  init(initialValue: Int) { // expected-note{{initializer 'init(initialValue:)' declared here}}
  }

  init(initialValue: Double) { // expected-note{{initializer 'init(initialValue:)' declared here}}
  }
}

@_propertyDelegate
struct InitialValueFailable<Value> {
  var value: Value

  init?(initialValue: Value) { // expected-error{{'init(initialValue:)' cannot be failable}}
    return nil
  }
}

@_propertyDelegate
struct InitialValueFailableIUO<Value> {
  var value: Value

  init!(initialValue: Value) {  // expected-error{{'init(initialValue:)' cannot be failable}}
    return nil
  }
}

// ---------------------------------------------------------------------------
// Property delegate type definitions
// ---------------------------------------------------------------------------
@_propertyDelegate
struct _lowercaseDelegate<T> { // expected-error{{property delegate type name must start with an uppercase letter}}
  var value: T
}

@_propertyDelegate
struct _UppercaseDelegate<T> {
  var value: T
}

// ---------------------------------------------------------------------------
// Limitations on where property delegates can be used
// ---------------------------------------------------------------------------

func testLocalContext() {
  @WrapperWithInitialValue // expected-error{{property delegates are not yet supported on local properties}}
  var x = 17
  x = 42
  _ = x
}

enum SomeEnum {
  case foo

  @Wrapper(value: 17)
  var bar: Int // expected-error{{property 'bar' declared inside an enum cannot have a delegate}}
  // expected-error@-1{{enums must not contain stored properties}}

  @Wrapper(value: 17)
  static var x: Int
}

protocol SomeProtocol {
  @Wrapper(value: 17)
  var bar: Int // expected-error{{property 'bar' declared inside a protocol cannot have a delegate}}
  // expected-error@-1{{property in protocol must have explicit { get } or { get set } specifier}}

  @Wrapper(value: 17)
  static var x: Int // expected-error{{property 'x' declared inside a protocol cannot have a delegate}}
  // expected-error@-1{{property in protocol must have explicit { get } or { get set } specifier}}
}

struct HasDelegate { }

extension HasDelegate {
  @Wrapper(value: 17)
  var inExt: Int // expected-error{{property 'inExt' declared inside an extension cannot have a delegate}}
  // expected-error@-1{{extensions must not contain stored properties}}

  @Wrapper(value: 17)
  static var x: Int
}

class ClassWithDelegates {
  @Wrapper(value: 17)
  var x: Int
}

class Superclass {
  var x: Int = 0
}

class SubclassWithDelegate: Superclass {
  @Wrapper(value: 17)
  override var x: Int { get { return 0 } set { } } // expected-error{{property 'x' with attached delegate cannot override another property}}
}

class C { }

struct BadCombinations {
  @WrapperWithInitialValue
  lazy var x: C = C() // expected-error{{property 'x' with a delegate cannot also be lazy}}
  @Wrapper
  weak var y: C? // expected-error{{property 'y' with a delegate cannot also be weak}}
  @Wrapper
  unowned var z: C // expected-error{{property 'z' with a delegate cannot also be unowned}}
}

struct MultipleDelegates {
  @Wrapper(value: 17) // expected-error{{only one property delegate can be attached to a given property}}
  @WrapperWithInitialValue // expected-note{{previous property delegate specified here}}
  var x: Int = 17

  @WrapperWithInitialValue // expected-error 2{{property delegate can only apply to a single variable}}
  var (y, z) = (1, 2)
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

struct Initialization {
  @Wrapper(value: 17)
  var x: Int

  @Wrapper(value: 17)
  var x2: Double

  @Wrapper(value: 17)
  var x3 = 42 // expected-error{{property 'x3' with attached delegate cannot initialize both the delegate type and the property}}

  @Wrapper(value: 17)
  var x4

  @WrapperWithInitialValue
  var y = true

  // FIXME: It would be nice if we had a more detailed diagnostic here.
  @WrapperWithInitialValue<Int>
  var y2 = true // expected-error{{'Bool' is not convertible to 'Int'}}

  mutating func checkTypes(s: String) {
    x2 = s // expected-error{{cannot assign value of type 'String' to type 'Double'}}
    x4 = s // expected-error{{cannot assign value of type 'String' to type 'Int'}}
    y = s // expected-error{{cannot assign value of type 'String' to type 'Bool'}}
  }
}

// ---------------------------------------------------------------------------
// Delegate type formation
// ---------------------------------------------------------------------------
@_propertyDelegate
struct IntWrapper {
  var value: Int
}

@_propertyDelegate
struct WrapperForHashable<T: Hashable> {
  var value: T
}

@_propertyDelegate
struct WrapperWithTwoParams<T, U> {
  var value: (T, U)
}

struct NotHashable { }

struct UseWrappersWithDifferentForm {
  @IntWrapper
  var x: Int

  @WrapperForHashable // expected-error{{type 'NotHashable' does not conform to protocol 'Hashable'}}
  var y: NotHashable

  @WrapperForHashable
  var yOkay: Int

  @WrapperWithTwoParams // expected-error{{property delegate type 'WrapperWithTwoParams' must either specify all generic arguments or require only a single generic argument}}
  var z: Int

  @HasNestedDelegate.NestedDelegate // expected-error{{property delegate type 'HasNestedDelegate.NestedDelegate<Int>' must either specify all generic arguments or require only a single generic argument}}
  var w: Int

  @HasNestedDelegate<Double>.NestedDelegate
  var wOkay: Int
}


// ---------------------------------------------------------------------------
// Nested delegates
// ---------------------------------------------------------------------------
struct HasNestedDelegate<T> {
  @_propertyDelegate
  struct NestedDelegate<U> {
    var value: U
    init(initialValue: U) {
      self.value = initialValue
    }
  }

  @NestedDelegate
  var y: [T] = []
}

struct UsesNestedDelegate<V> {
  @HasNestedDelegate<V>.NestedDelegate
  var y: [V]
}

// ---------------------------------------------------------------------------
// Referencing the backing store
// ---------------------------------------------------------------------------
struct BackingStore<T> {
  @Wrapper
  var x: T

  @WrapperWithInitialValue
  private var y = true  // expected-note{{'y' declared here}}

  func getXStorage() -> Wrapper<T> {
    return $x
  }

  func getYStorage() -> WrapperWithInitialValue<Bool> {
    return self.$y
  }
}

func testBackingStore<T>(bs: BackingStore<T>) {
  _ = bs.x
  _ = bs.y // expected-error{{'y' is inaccessible due to 'private' protection level}}
}

// ---------------------------------------------------------------------------
// Explicitly-specified accessors
// ---------------------------------------------------------------------------
struct DelegateWithAccessors {
  @Wrapper
  var x: Int {
    return $x.value * 2
  }

  @WrapperWithInitialValue
  var y: Int {
    get {
      return $y.value
    }

    set {
      $y.value = newValue / 2
    }
  }

  mutating func test() {
    x = y
    y = x
  }
}

struct UseWillSetDidSet {
  @Wrapper
  var x: Int {
    willSet {
      print(newValue)
    }
  }

  @Wrapper
  var y: Int {
    didSet {
      print(oldValue)
    }
  }

  @Wrapper
  var z: Int {
    willSet {
      print(newValue)
    }

    didSet {
      print(oldValue)
    }
  }
}

// ---------------------------------------------------------------------------
// Mutating/nonmutating
// ---------------------------------------------------------------------------
@_propertyDelegate
struct DelegateWithNonMutatingSetter<Value> {
  class Box {
    var value: Value
    init(value: Value) {
      self.value = value
    }
  }

  var box: Box

  init(initialValue: Value) {
    self.box = Box(value: initialValue)
  }

  var value: Value {
    get { return box.value }
    nonmutating set { box.value = newValue }
  }
}

@_propertyDelegate
struct DelegateWithMutatingGetter<Value> {
  var readCount = 0
  var writeCount = 0
  var stored: Value

  init(initialValue: Value) {
    self.stored = initialValue
  }

  var value: Value {
    mutating get {
      readCount += 1
      return stored
    }
    set {
      writeCount += 1
      stored = newValue
    }
  }
}

@_propertyDelegate
class ClassDelegate<Value> {
  var value: Value

  init(initialValue: Value) {
    self.value = initialValue
  }
}

struct UseMutatingnessDelegates {
  @DelegateWithNonMutatingSetter
  var x = true

  @DelegateWithMutatingGetter
  var y = 17

  @DelegateWithNonMutatingSetter // expected-error{{property delegate can only be applied to a 'var'}}
  let z = 3.14159 // expected-note 2{{change 'let' to 'var' to make it mutable}}

  @ClassDelegate
  var w = "Hello"
}

func testMutatingness() {
  var mutable = UseMutatingnessDelegates()

  _ = mutable.x
  mutable.x = false

  _ = mutable.y
  mutable.y = 42

  _ = mutable.z
  mutable.z = 2.71828 // expected-error{{cannot assign to property: 'z' is a 'let' constant}}

  _ = mutable.w
  mutable.w = "Goodbye"

  let nonmutable = UseMutatingnessDelegates() // expected-note 2{{change 'let' to 'var' to make it mutable}}

  // Okay due to nonmutating setter
  _ = nonmutable.x
  nonmutable.x = false

  _ = nonmutable.y // expected-error{{cannot use mutating getter on immutable value: 'nonmutable' is a 'let' constant}}
  nonmutable.y = 42 // expected-error{{cannot use mutating getter on immutable value: 'nonmutable' is a 'let' constant}}

  _ = nonmutable.z
  nonmutable.z = 2.71828 // expected-error{{cannot assign to property: 'z' is a 'let' constant}}

  // Okay due to implicitly nonmutating setter
  _ = nonmutable.w
  nonmutable.w = "World"
}

// ---------------------------------------------------------------------------
// Access control
// ---------------------------------------------------------------------------
struct HasPrivateDelegate<T> {
  @_propertyDelegate
  private struct PrivateDelegate<U> { // expected-note{{type declared here}}
    var value: U
    init(initialValue: U) {
      self.value = initialValue
    }
  }

  @PrivateDelegate
  var y: [T] = []
  // expected-error@-1{{property must be declared private because its property delegate type uses a private type}}

  // Okay to reference private entities from a private property
  @PrivateDelegate
  private var z: [T]
}

public struct HasUsableFromInlineDelegate<T> {
  @_propertyDelegate
  struct InternalDelegate<U> { // expected-note{{type declared here}}
    var value: U
    init(initialValue: U) {
      self.value = initialValue
    }
  }

  @InternalDelegate
  @usableFromInline
  var y: [T] = []
  // expected-error@-1{{property delegate type referenced from a '@usableFromInline' property must be '@usableFromInline' or public}}
}

@_propertyDelegate
class Box<Value> {
  private(set) var value: Value

  init(initialValue: Value) {
    self.value = initialValue
  }
}

struct UseBox {
  @Box
  var x = 17

  @Box
  var y: Int {
    get { return $y.value }
    set { }
  }
}

func testBox(ub: UseBox) {
  _ = ub.x
  ub.x = 5 // expected-error{{cannot assign to property: 'x' is a get-only property}}

  _ = ub.y
  ub.y = 20 // expected-error{{cannot assign to property: 'ub' is a 'let' constant}}

  var mutableUB = ub
  _ = mutableUB.y
  mutableUB.y = 20
  mutableUB = ub
}

// ---------------------------------------------------------------------------
// Memberwise initializers
// ---------------------------------------------------------------------------
struct MemberwiseInits<T> {
  @Wrapper
  var x: Bool

  @WrapperWithInitialValue
  var y: T
}

func testMemberwiseInits() {
  // expected-error@+1{{type '(Wrapper<Bool>, Double) -> MemberwiseInits<Double>'}}
  let _: Int = MemberwiseInits<Double>.init

  _ = MemberwiseInits(x: Wrapper(value: true), y: 17)
}

struct DefaultedMemberwiseInits {
  @Wrapper(value: true)
  var x: Bool

  @WrapperWithInitialValue
  var y: Int = 17

  @WrapperWithInitialValue(initialValue: 17)
  var z: Int
}

func testDefaultedMemberwiseInits() {
  _ = DefaultedMemberwiseInits()
  _ = DefaultedMemberwiseInits(
    x: Wrapper(value: false),
    y: 42,
    z: WrapperWithInitialValue(initialValue: 42))

  _ = DefaultedMemberwiseInits(y: 42)
  _ = DefaultedMemberwiseInits(x: Wrapper(value: false))
  _ = DefaultedMemberwiseInits(z: WrapperWithInitialValue(initialValue: 42))
}

// ---------------------------------------------------------------------------
// Default initializers
// ---------------------------------------------------------------------------
struct DefaultInitializerStruct {
  @Wrapper(value: true)
  var x

  @WrapperWithInitialValue
  var y: Int = 10
}

struct NoDefaultInitializerStruct { // expected-note{{'init(x:)' declared here}}
  @Wrapper
  var x: Bool
}

class DefaultInitializerClass {
  @Wrapper(value: true)
  final var x

  @WrapperWithInitialValue
  final var y: Int = 10
}

class NoDefaultInitializerClass { // expected-error{{class 'NoDefaultInitializerClass' has no initializers}}
  @Wrapper
  final var x: Bool  // expected-note{{stored property 'x' without initial value prevents synthesized initializers}}
}

func testDefaultInitializers() {
  _ = DefaultInitializerStruct()
  _ = DefaultInitializerClass()
  _ = NoDefaultInitializerStruct() // expected-error{{missing argument for parameter 'x' in call}}
}

// ---------------------------------------------------------------------------
// Storage references
// ---------------------------------------------------------------------------
@_propertyDelegate
struct WrapperWithStorageRef<T> {
  var value: T

  var delegateValue: Wrapper<T> {
    return Wrapper(value: value)
  }
}

extension Wrapper {
  var wrapperOnlyAPI: Int { return 17 }
}

struct TestStorageRef {
  @WrapperWithStorageRef var x: Int // expected-note{{'$$x' declared here}}

  init(x: Int) {
    self.$$x = WrapperWithStorageRef(value: x)
  }

  mutating func test() {
    let _: Wrapper = $x
    let i = $x.wrapperOnlyAPI
    let _: Int = i

    // x is mutable, $x is not
    x = 17
    $x = Wrapper(value: 42) // expected-error{{cannot assign to property: '$x' is immutable}}
  }
}

func testStorageRef(tsr: TestStorageRef) {
  let _: Wrapper = tsr.$x
  _ = tsr.$$x // expected-error{{'$$x' is inaccessible due to 'private' protection level}}
}

// ---------------------------------------------------------------------------
// Misc. semantic issues
// ---------------------------------------------------------------------------
@_propertyDelegate
struct BrokenLazy { }
// expected-error@-1{{property delegate type 'BrokenLazy' does not contain a non-static property named 'value'}}
// expected-note@-2{{'BrokenLazy' declared here}}

struct S {
  @BrokenLazy // expected-error{{struct 'BrokenLazy' cannot be used as an attribute}}
  var value: Int
}

// ---------------------------------------------------------------------------
// Closures in initializers
// ---------------------------------------------------------------------------
struct UsesExplicitClosures {
  @WrapperAcceptingAutoclosure(body: { 42 })
  var x: Int

  @WrapperAcceptingAutoclosure(body: { return 42 })
  var y: Int
}
