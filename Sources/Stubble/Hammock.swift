// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(member, names: named(Mock))
public macro Mockable() = #externalMacro(module: "StubbleMacros", type: "MockableMacro")

@attached(memberAttribute)
public macro Stubbable() = #externalMacro(module: "StubbleMacros", type: "StubbableMacro")

@attached(body)
@attached(peer, names: prefixed(_))
public macro StubbableFunction() = #externalMacro(module: "StubbleMacros", type: "StubbableFunctionMacro")

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(_), prefixed(_get), prefixed(_set), arbitrary)
public macro StubbableProperty() = #externalMacro(module: "StubbleMacros", type: "StubbablePropertyMacro")
