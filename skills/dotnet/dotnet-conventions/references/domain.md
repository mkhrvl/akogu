# Domain conventions

## Expected failures

Represent expected business, validation, not-found, and conflict outcomes as result values rather than exceptions. Use the repository's established result abstraction; one result type per codebase. When the repository has none, use `ErrorOr<T>` unless project requirements indicate otherwise.

Choose the error type by what the caller did wrong, because it decides the HTTP status (see [HTTP](http.md#error-responses)):

| ErrorOr type | Use for |
| --- | --- |
| `Validation` | Malformed or structurally invalid input, including invalid values rejected by a factory |
| `Failure` | Well-formed input rejected by a business rule |
| `NotFound` | The addressed resource does not exist |
| `Conflict` | Duplicates, stale state, or an invalid concurrent transition |
| `Unauthorized` / `Forbidden` | Missing authentication / insufficient permission |

`NotFound` is only for the resource the request addresses, usually by its route. A request value that references a missing or unusable entity, such as an unknown or inactive branch code in the body, is `Validation` of that field: the caller fixes it by changing the value.

Reserve exceptions for programming-contract violations, broken invariants or corrupted state, unexpected infrastructure failures, and framework exception contracts. Catch only a specific exception the current boundary can recover from, translate, enrich, or compensate for. Clean up with `using`, `await using`, or `finally`; rethrow with `throw;` and keep the original as `InnerException` when wrapping. Log an exception once, at the boundary that handles it. Caller cancellation propagates as `OperationCanceledException`, never as a result error.

## Error catalogs

Every expected error carries a stable, namespaced code (`Foo.InvalidCode`) that clients can react to without parsing messages or depending on property names. Keep codes free of credentials, tokens, keys, personal data, and downstream response bodies, and treat a code change as a contract change.

Define errors in an `internal static` catalog in its own same-named `*Errors.cs` file, owned by the domain concept, feature, or operation: `FooErrors`, `FooFeatureErrors`, or `CreateFooErrors`. Factories and behavior methods return catalog entries rather than constructing errors inline, which keeps codes and descriptions stable and lets tests and HTTP mapping reference them.

```csharp
internal static class FooErrors
{
    public static readonly Error InvalidCode =
        Error.Validation("Foo.InvalidCode", "Foo code must be 3 to 20 characters.");

    public static readonly Error AlreadyCompleted =
        Error.Failure("Foo.AlreadyCompleted", "A completed foo cannot be changed.");
}
```

FluentValidation rules set the same kind of code with `.WithErrorCode("Foo.NameRequired")`; the property name travels separately as the error's `name`, never as its code.

## Validation and construction

Validate transport shape at the boundary (required fields, lengths, formats, ranges) and enforce domain invariants and business rules in domain types. The two may overlap on purpose: early feedback at the edge, invariant protection at the core. Data-dependent conditions belong in the handler.

Construct externally sourced domain objects through validating factories so every successfully constructed value is valid. Use a private constructor that assigns already-valid values and a named factory that validates and normalizes. Name the primary result-returning factory `Create`; reserve `TryCreate` for `bool`/`out`, `Parse`/`TryParse` for text, and a domain name such as `CreatePending` or `Restore` for a materially different workflow.

```csharp
internal sealed record FooCode
{
    private FooCode(string value) => Value = value;

    public string Value { get; }

    public static ErrorOr<FooCode> Create(string value)
    {
        var normalizedValue = value.Trim();
        return normalizedValue.Length is < 3 or > 20
            ? FooErrors.InvalidCode
            : new FooCode(normalizedValue);
    }

    public override string ToString() => Value;
}
```

## Entities and value objects

Model entities as classes with stable identity and behavior-controlled state. Expose changes through intention-named methods with private or absent setters; persistence-shaped public mutation leaks invariants. Back mutable collections with private fields, expose `IReadOnlyCollection<T>` (or `IReadOnlyList<T>` when order matters) via `AsReadOnly()`, and mutate only through invariant-preserving methods. Keep reference equality unless identifier equality is explicitly needed. Coordinate rules that span aggregates in the application handler.

```csharp
internal sealed class Foo
{
    private readonly List<FooItem> _items = [];

    public IReadOnlyCollection<FooItem> Items => _items.AsReadOnly();
    public FooStatus Status { get; private set; }

    public ErrorOr<Success> AddItem(FooItem item)
    {
        if (Status is FooStatus.Completed)
            return FooErrors.AlreadyCompleted;

        _items.Add(item);
        return Result.Success;
    }
}
```

Model value objects as immutable value-equality types, using records when their generated semantics match. Expose the scalar through a read-only `Value` and unwrap explicitly at infrastructure and serialization boundaries; implicit conversions to or from primitives weaken the type safety the value object exists for. Override `ToString()` to return the textual form, since a record's generated `ToString()` prints `FooCode { Value = ABC }` into logs and strings. Use dedicated serializer and ORM converters.

Introduce a value object when a primitive carries a normalization or validity rule that more than one place depends on, or when it travels between domain, handlers, and ports. Judge the cost by the readability of domain and handler code; converters and mapping at infrastructure and serialization boundaries are a one-time cost and do not count against it. A value object that enforces such a rule is an invariant, not speculative abstraction, so a "fewer moving parts" preference does not argue against it. Avoid static normalizer helpers over raw strings (`Codes.Normalize(value)`): every caller must remember to apply them, and the type cannot say whether a value is already normalized. Keep closed sets as enums and free text as strings.

Use raw `Guid` identifiers where scope makes confusion unlikely. Introduce a strongly typed identifier when several identifiers coexist, cross a domain boundary, or mixing them up would be costly; one that appears in routes or query strings implements `IParsable<T>` so binding works.

```csharp
internal readonly record struct FooId(Guid Value) : IParsable<FooId>
{
    public override string ToString() => Value.ToString();

    public static FooId Parse(string s, IFormatProvider? provider) => new(Guid.Parse(s, provider));

    public static bool TryParse(string? s, IFormatProvider? provider, out FooId result)
    {
        var parsed = Guid.TryParse(s, provider, out var value);
        result = new FooId(value);
        return parsed;
    }
}
```

## Enums and states

Use ordinary enums for small closed sets. Use distinct typed states when alternatives carry different mandatory data or operations that would otherwise become conditionally valid nullable properties, and smart-enum classes for alternatives sharing metadata or behavior. A switch is not a reason for a state hierarchy.

Serialize enums as stable string names in APIs, messages, and configuration by registering `JsonStringEnumConverter` in every serializer options instance (ASP.NET Core JSON options, FastEndpoints serializer options, each integration's options), and persist them as strings by default with `HasConversion<string>()`. The names become contract values. Store numbers only for legacy schemas, external numeric codes, or a demonstrated need, with permanent explicit values. Map explicitly when CLR names must evolve independently of wire or storage values.

## Time

- `DateTimeOffset` for instants, normalized to UTC for persistence and comparison; a `Utc` suffix where it clarifies policy.
- `DateOnly` for calendar dates, `TimeOnly` for wall-clock times, `TimeSpan` for durations. Future local schedules keep the time-zone identifier with the local date and time.
- Plain `DateTime` stays out of application and API contracts; convert explicitly where a framework, database provider, or external contract requires it, and name such values with a `Utc` suffix.

Application code obtains the current time from an injected `TimeProvider`. Domain types receive time as a parameter: the application captures the instant once per logical operation and passes it in, so one operation uses one consistent "now".

## Money

Represent amounts as `decimal`, never `double`. Document one rounding rule: the `MidpointRounding` mode and the stage where rounding happens (per line, per total, only at presentation). Configure explicit database precision and scale for every money column. Pair amounts with a currency code whenever more than one currency or an external financial contract is possible; operations on mismatched currencies fail rather than convert silently.
