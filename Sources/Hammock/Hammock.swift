// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(member, names: named(Mock))
public macro Mockable() = #externalMacro(module: "HammockMacros", type: "MockableMacro")

@attached(memberAttribute)
public macro Stubbable() = #externalMacro(module: "HammockMacros", type: "StubbableMacro")

@attached(peer, names: prefixed(_))
@attached(body)
public macro StubbableMember() = #externalMacro(module: "HammockMacros", type: "StubbableMemberMacro")
