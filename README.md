# Anaconda

A stock-watchlist iOS app with a live price stream, offline support and a legacy order-ticket screen. Built for testability: the goal is to look at any Swift class and see its seams, its hidden dependencies and how to test it.

## Structure

```
Anaconda/        iOS app target (composition root)
Packages/
  Core/          domain models and protocols, no dependencies
  Networking/    remote clients, depends on Core
  Persistence/   local storage and cache, depends on Core
  Features/      view models and views, depends on Core, Networking, Persistence
```

Every dependency is injected through a protocol and an initializer. No real network in tests.

## Testing

Each package has its own test target:

```
cd Packages/<Package> && swift test
```

CI runs the unit tests on every push and pull request.

## Status

Work in progress. Setting up the project structure and CI.
