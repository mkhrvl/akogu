# C# conventions

Formatting and mechanically enforceable style belong to CSharpier, `.editorconfig`, and analyzers; these rules cover what needs judgement.

## Types and visibility

Declare classes and record classes `internal sealed` by default; other type kinds (interfaces, enums, structs, static classes) default to `internal`. Make a type `public` only when another assembly consumes it or a framework requires it, and leave a class unsealed only when it is designed for inheritance. xUnit test classes are the common case: they must be `public` (analyzer xUnit1000), so declare them `public sealed`. Test projects reach internal types through `<InternalsVisibleTo Include="<Name>.Tests.Unit" />` (and the other test assemblies) in the production project file.

Give each top-level type its own file named after the type. Exceptions: tightly coupled immutable records forming one snapshot, and request subtypes used only by their primary request.

## Constructors and dependencies

Use traditional constructors for any type that receives dependencies: handlers, endpoints, services, adapters, middleware, workers, and test helpers. Store each dependency in a `private readonly` `_camelCase` field, so a reviewer can tell injected dependencies from locals, parameters, and mutable state at a glance.

Primary constructors fit records and pure pass-through types whose parameters only flow to a base constructor or initializers, such as `class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)`. Set `csharp_style_prefer_primary_constructors = false` so tooling does not suggest conversions.

```csharp
internal sealed class FooService
{
    private readonly IFooClient _fooClient;

    public FooService(IFooClient fooClient) => _fooClient = fooClient;

    public Task SendAsync(CancellationToken cancellationToken) =>
        _fooClient.SendAsync(cancellationToken);
}
```

Validate arguments of public reusable types, uncontrolled callers, and external values. Non-nullable dependencies supplied only by the DI container need no null guards.

## Records and initialization

Use records for immutable Commands, Queries, Results, and value-like contracts. Choose positional or nominal form by readability at both declaration and construction sites: positional for trivial contracts where each argument stays obvious; nominal with named initialization for many members, repeated primitives, optional values, or evolving fields.

Use `required` for mandatory object-initialized properties, nullable properties for optional values, and initializers for intentional defaults. `required` enforces initialization, nullability says whether `null` is valid, and validation decides structural or business validity; keep the three distinct rather than adding placeholder defaults to quiet nullable analysis. Keep collections non-nullable and initialized to `[]` when omission means no items; make one nullable only when omitted and empty differ.

```csharp
internal sealed record CreateFooCommand
{
    public required string Code { get; init; }
    public required string Name { get; init; }
    public string? Description { get; init; }
    public IReadOnlyList<string> Tags { get; init; } = [];
}
```

HTTP request DTOs are the exception: they use nullable properties without `required`, because System.Text.Json rejects a missing `required` property before the validator runs (see [HTTP](http.md#inbound-endpoints)).

## Expressions

Use `var` when construction or a simple transformation makes the type apparent; state the type when the result shape, nullability, or domain meaning benefits from being visible. Use collection expressions when the target type is clear and no comparer, capacity, or specialized construction is needed. Use expression bodies for trivial forwarding, formatting, or error definitions, and block bodies for branching, validation, data access, or orchestration.

## Member order and helpers

Within a type order constants and fields; properties, indexers, and events; constructors; methods; then nested types. Put public and protected methods before private helpers, keep related methods together, and order private helpers by their first public caller. Group helpers by responsibility when a type has several substantial workflows. Static or instance scope does not override the order; positional records are exempt.

Use a local function only when it is small, algorithmic, used by one method, and clearer beside its caller: parsing, traversal, formatting, or calculation details. Use a private method for I/O, mapping, validation, persistence, communication, domain behavior, substantial branching, or behavior that may grow independently. Endpoints, handlers, and workers default to private methods.

## Comments and documentation

Comment only a non-obvious why, constraint, workaround, or trade-off that names and structure cannot carry, and leave rationale recorded in an ADR to the ADR. Require XML documentation for public APIs, reusable libraries, and framework extension points whose consumers need contract, usage, exception, lifecycle, ownership, thread-safety, or call-order information; such library projects set `<GenerateDocumentationFile>true</GenerateDocumentationFile>` so CS1591 reports gaps. Ordinary implementation details go without.

## Async and cancellation

Propagate cancellation wherever it stays meaningful. Endpoints, handlers, workers, and consumers accept the framework token; repositories, HTTP clients, database and file operations, and cancellable helpers accept and pass it on; long CPU loops check it periodically. Short mapping, validation, formatting, and domain methods take no token. Pass the caller's token to every cancellable operation rather than `CancellationToken.None`. After a commit or external side effect, decide deliberately whether cleanup or reconciliation must continue despite caller cancellation.

Suffix every awaitable-returning method with `Async`, including private methods and methods that return a `Task` without the `async` keyword, unless a fixed contract dictates the name; the `.editorconfig` rule catches only methods marked `async`, so review the rest. Use `ValueTask` only for a required contract or a measured allocation win on a hot path that often completes synchronously, and await it exactly once. `async void` is only for framework-mandated event handlers, which must handle their own exceptions.

Use `async`/`await` through the whole call chain, tests included. `.Result`, `.Wait()`, `Task.WaitAll()`, and `.GetAwaiter().GetResult()` appear only inside an unchangeable synchronous adapter, with a comment naming the constraint.

Use plain `await` in application code; reserve `ConfigureAwait(false)` for reusable libraries. Await request work directly. `Task.Run` is for intentional bounded CPU parallelism only: not for wrapping async I/O, hiding synchronous I/O, or launching fire-and-forget request work.

Every asynchronous operation is either awaited or handed to an explicit owner that observes exceptions, bounds concurrency, honors cancellation, and participates in shutdown: a bounded hosted queue or task tracker for process-local work, or an outbox, broker, or durable job for work that must survive a crash.

## Background services

A `BackgroundService` runs its loop directly in `ExecuteAsync`. An unhandled exception stops the whole host by default, so a long-running loop catches, logs, and continues per iteration, and lets `OperationCanceledException` from the stopping token end the loop. Wait between iterations with `PeriodicTimer` or `TimeProvider`-based delays rather than `Thread.Sleep` or unbounded `Task.Delay` chains. A one-shot worker that must signal failure to its orchestrator sets `Environment.ExitCode` to non-zero before stopping the application; a thrown exception alone exits with code 0.
