// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(member, names: named(Mock))
public macro Mockable() = #externalMacro(module: "HammockMacros", type: "MockableMacro")

@attached(body)
public macro Stubbable() = #externalMacro(module: "HammockMacros", type: "StubbableBodyMacro")
