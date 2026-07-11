# Code Style Guide

## Naming

- **Types** (structs, classes, enums, protocols): `PascalCase`
- **Variables, functions, enum cases**: `camelCase`
- **Files**: `PascalCase.swift` matching the primary type
- **Protocols**: `DescriptiveName` or `DescriptiveNameProtocol` if conflicting with Foundation
- **Booleans**: `isLoading`, `hasPremium`, `showSplash` (prefix with `is`/`has`/`show`)

## Formatting

- **Indentation**: 4 spaces
- **Braces**: Same line for types, methods, control flow
- **Colons**: Space after, no space before (`let name: String`, `[String: Any]`)
- **Line length**: Aim for < 120 characters

## Patterns

### View Organization
```swift
struct SomeView: View {
    // 1. @State, @Binding, @StateObject, @EnvironmentObject
    // 2. @AppStorage, @Environment
    // 3. Constants (let/var)
    // 4. Body (computed property)
    // 5. Private view builders
    // 6. Private methods
}
```

### Service Organization
```swift
actor SomeService {
    static let shared = SomeService()

    // Public async methods
    func doSomething() async throws -> Data

    // Private helpers
    private func helper()
}
```

## Swift Conventions

- Prefer `let` over `var` where possible
- Use implicit return for single-expression functions
- Use `guard` for early returns, `if` for positive flows
- Use `switch` over `if-else if` chains with enums
- Use `map`, `compactMap`, `filter` over manual loops where clarity isn't sacrificed
- Use `defer` for cleanup (security-scoped resources, etc.)

## iOS-Specific

- Use `@MainActor` for observable objects and UI-bound classes
- Use `.task { }` for async work in views, not `.onAppear` with `Task { }`
- Use `@AppStorage` for user defaults, not `UserDefaults.standard` directly
- Use `@EnvironmentObject` for shared singletons, not manual passing
- Format dates using `formatted(.dateTime ...)` API, not `DateFormatter`
- Use `ByteCountFormatter` for file sizes

## Error Handling

```swift
enum AppError: LocalizedError {
    case somethingFailed

    var errorDescription: String? { "Something failed." }
}
```

- Errors use `LocalizedError` with `errorDescription`
- Propagate with `throws`; catch at the view level with `.alert(error)`
