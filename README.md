# Stubble

Stubble is a proof of concept, macro-based stubbing library for Swift. The design, implementation, and evaluation of Stubble was the subject of my master's paper. You can find the full paper [here](./Stubble-Paper.pdf).

Using Swift's new macro system, Stubble allows you to easily stub the implementations of a type's methods or property getters/setters. It can be as simple as adding the `@Stubbable` attribute to your struct, class, or actor. Or, you can selectively apply `@StubbableFunction` and `@StubbableProperty` to just the declarations that you'd like to stub.

Rather than requiring you to create a protocol and a parralel stub implementation that match the API surface of the type you'd like to stub, Stubble uses macros to generate the stubbing infrastructure directly inside of your type. Drastically reducing the amount of boilerplate code needed to add stubbing to a project.

## Usage

Stubbable provides three macros – `@StubbableFunction`, `@StubbableProperty`, and `@Stubbable`.

### `@StubbableFunction`

The `@StubbableFunction` macro, when applied to a supported function signature, does two things.
1. Generates a property that optionally stores a closure with the same type as the function.
2. Replaces the body of the function to call the peer closure, if possible.

```swift
class RosterService {
    @StubbableFunction
    func fetchStudents() async throws -> [Student] {
        // make an HTTP request
        return response
    }
}

// Expands to:
class RosterService {
    var _fetchStudents: (() async throws -> [Student])? = nil

    func fetchStudents() async throws -> [Student] {
        if let _fetchStudents {
            return try await _fetchStudents()
        } else {
            // make an HTTP request
            return response
        }
    }
}
```

Then, in your test suite, you can stub the function in question by providing a closure to be called, rather than the original function body.

```swift
let service = RosterService()
service._fetchStudents = { return [] }

let students = try await service.fetchStudents() // always returns []
```

### `@StubbableProperty`

Similarly, the `@StubbableProperty` macro allows you to stub the implementations of instance property getters and setters. This macro does the following:
1. Generates optional, peer getter & setters closures for the type of the property.
2. Generates a peer, stored property that will be the actual storage of this property.
3. Turns the property declaration in question into a computed property – adding `init`, `get`, and `set` accessors with the desired functionality.

```swift
class FeatureFlag {
    @StubbableProperty
    var isEnabled: Bool
    
    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

// Expands to:

class FeatureFlag {
    private var _isEnabled: Bool
    var _getIsEnabled: (() -> Bool)? = nil
    var _setIsEnabled: ((Bool) -> Void)? = nil
    
    var isEnabled: Bool {
        get {
            if let _getIsEnabled {
                return _getIsEnabled()
            } else {
                return _isEnabled
            }
        }
        set {
            if let _setIsEnabled {
                _setIsEnabled(newValue)
            } else {
                _isEnabled = newValue
            }
        }
        @storageRestrictions(initializes: _isEnabled)
        init(initialValue) {
            _isEnabled = initialValue
        }
    }
    
    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}
```

Then, you can stub the getter & setter implementations by writing to the getter & setter closure properties.

```swift
let stub = FeatureFlag()
stub._getIsEnabled = { return true }
stub._setIsEnabled = { print("Flag is enabled: \($0)") }
```

### `@Stubbable`

Lastly, Stubble offers a type-level convenience macro to add stubbing capabilities for an entire type with a single macro application rather than needing to apply macros to all of the type’s members: `@Stubbable`. This macro visits each member in the type’s declaration and inspects its syntax to decide if it should receive `@StubbableFunction`, `@StubbableProperty`, or no new annotations at all. In the following example, it sees an instance property and an instance method, and applies `@StubbableProperty` and `@StubbableFunction` accordingly:

```swift
@Stubbable
class RosterService {
    var courses: [Course] = []
    
    func fetchAllStudents() async throws -> [Student] {
        // fetch students in all courses from server
        return allStudents
    }
}

// Expands to:

class RosterService {
    @StubbableProperty
    var courses: [Course] = []

    @StubbableFunction
    func fetchAllStudents() async throws -> [Student] {
        // fetch students in all courses from server
        return allStudents
    }
}
```

Then, `@StubbableFunction` and `@StubbableProperty` perform their expansions as described above, and developers can stub the functions and properties as usual.
