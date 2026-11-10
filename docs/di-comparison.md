# Dependency injection: manual vs Factory vs Swinject vs swift-dependencies

All four answer the same question: where do a type's dependencies come from, and how does a test swap them?

| | Manual DI | Factory | Swinject | swift-dependencies |
|---|---|---|---|---|
| Wiring | Hand-written composition root | `extension Container`, one `Factory<T>` per dependency | `register` / `resolve` at startup | `DependencyKey` + `DependencyValues` |
| Used in a type | `init(repository:)` | `@Injected(\.x)` | `resolve(T.self)` | `@Dependency(\.x)` |
| Missing dependency | Compile error | Compile error (key paths) | Runtime crash | Compile error; unmocked in tests uses `testValue` |
| Test override | Pass a fake to `init` | `register { }` on `Container.shared`, then `reset()` | Re-register in a test container | `withDependencies { } operation: { }`, scoped |
| Dependencies visible in `init` | Yes | No (wrapper) | Depends on use | No (wrapper) |
| Global state | None | `Container.shared` | The container | Scoped context |
| Spreads through the codebase | No | Only if used inside types | Only if used inside types | Yes, by design |

## Trade-offs

- **Manual** is explicit and safe. A type's needs are in its `init`, the compiler checks every one, and tests need no library. Cost: the root grows with the app and passing things down gets repetitive.
- **Factory** removes most of the boilerplate and has scopes (singleton, cached). Cost: property wrappers hide dependencies from `init`, and overrides go through global state, so every test must `reset()`.
- **Swinject** is mature and flexible. Cost: resolution is by type at runtime, so a missing registration crashes at runtime and `resolve(...)!` is common.
- **swift-dependencies** has the best testing story: scoped overrides, built-in `date`/`uuid`/clock, and unmocked dependencies fail loudly. Cost: it is viral. It is meant to be used inside domain types, so every package that uses it imports the library and adopts its model.

## The lock-in point

Property-wrapper styles (`@Injected`, `@Dependency`) spread. Once one type uses them, its callers, tests and sibling packages follow, and `Core` / `Features` stop being library-free. Container-only use (Factory or Swinject in the app target, with explicit `init`s everywhere else) contains the cost, but then the library only replaces the wiring code in the root.

## Decision for this app

**Manual DI.** Constructor injection in every type, one composition root (`AppDependencies`), a fake for each dependency in tests. The root is about 30 lines. A library saves nothing yet and would add an import to every package.

**Revisit when** the root's wiring becomes the main source of churn (many features, many scopes). Then adopt a container (Factory) in the **app target only**, keep every type's explicit `init`, and do not let `@Injected` or `@Dependency` into `Core` or `Features`.

## Interview answer (30 seconds)

> I start with constructor injection and a single composition root, because it's explicit, compiler-checked and library-free. Libraries like Factory, Swinject or swift-dependencies automate the wiring, but the property-wrapper ones hide dependencies from `init` and spread through the codebase, so I'd only bring one in once the root's boilerplate actually hurts, and I'd keep it in the app target so the domain packages stay clean. If I wanted the strongest testing story and was already in the Point-Free ecosystem, I'd pick swift-dependencies.
