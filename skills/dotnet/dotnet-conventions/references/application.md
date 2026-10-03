# Application conventions

## Composition and dependency injection

`Program.cs` is the composition root: it composes subsystems and keeps middleware and endpoint ordering visible. Each feature area, module, or infrastructure subsystem exposes one focused registration extension such as `AddFoo(...)` in a `DependencyInjection.cs`, which owns its options, validation, services, handlers, and hosted services. Infrastructure adapters, typed `HttpClient`s, and their resilience are registered by the `Infrastructure` side (`AddFooInfrastructure()` or the subsystem's registration), because features do not reference adapter types. Split independent concerns into internal extensions by responsibility, not line count.

Register explicitly. Two assembly scans are accepted framework norms: FastEndpoints endpoint discovery and FluentValidation's `AddValidatorsFromAssemblyContaining<T>()`. Validators are stateless, so register them as singletons (`ServiceLifetime.Singleton`) unless one needs a scoped dependency. Any other scanning or generic registration layer needs a demonstrated need.

Choose lifetimes by ownership and state:

- **Singleton**: thread-safe, holds no request state, depends on no scoped service. Performance alone is no reason.
- **Scoped**: request or operation work, units of work, EF Core contexts, a shared transaction.
- **Transient**: lightweight and stateless, when each resolution should be new.

Resolve scoped services only inside a scope; a hosted service creates and disposes a scope per unit of work.

Declare dependencies in constructors. Express deferred or dynamic selection through a focused factory, keyed-service adapter, or other typed abstraction. Infrastructure may resolve manually only for framework integration, plugin dispatch, dynamic activation, or scope creation (prefer `IServiceScopeFactory`); keep that resolution at the boundary, never pass `IServiceProvider` into application or domain code, and never hold a scoped service beyond its scope.

Introduce an interface for an architectural boundary, independent evolution, multiple or dynamic implementations, a decorator, or a replaceable consumer. A stable deterministic component is injected and tested as its concrete type; an interface that exists only to make a class mockable is overhead. Wrap a framework capability only when the wrapper hides meaningful behavior, not a single call.

## Configuration and options

Bind related settings to a cohesive, strongly typed options class with the `Options` suffix, and inject it rather than reading configuration keys in application or domain code. Reserve `Settings` for persisted or administrator-editable application settings. A type bound to one fixed section exposes `public const string SectionName`. Name options after their configuration concept; do not share one options type across unrelated integrations because their shapes match.

Register the full chain; `AddOptionsWithValidateOnStart` alone runs no data-annotation validation:

```csharp
services.AddOptionsWithValidateOnStart<FooOptions>()
    .BindConfiguration(FooOptions.SectionName)
    .ValidateDataAnnotations();

services.AddSingleton<IValidateOptions<FooOptions>, FooOptionsValidator>();
```

Use data annotations for simple required, range, and length rules and `IValidateOptions<TOptions>` for cross-property, conditional, or semantic rules, stating each rule once. Type URLs as `Uri` and validate absoluteness and scheme in the options validator; `[Url]` checks only strings and accepts FTP. Options are binding models: `init` for startup-bound values, `set` where reload or binding needs it; `required` never replaces runtime validation. Give an options type and its validator separate files.

Read options at runtime through `IOptions<T>` (or the service provider during registration callbacks), never by binding configuration by hand before validation has run. Use `IOptionsSnapshot<T>` only for scoped values refreshed per request, and `IOptionsMonitor<T>` only when a singleton must observe runtime changes. Add reloadability only for a concrete requirement.

Treat `appsettings.json` as the complete configuration shape: safe defaults where they exist, `null` for externally supplied secrets, and an empty string for required environment-specific values with no safe default, all validated at startup. Environment files hold only genuine overrides, in the same order as the base file. `Development` is local-only and its automatic behavior stays isolated from shared environments; data-mutating development behavior requires explicit opt-in.

Keep local secrets in user secrets and deployed secrets in the deployment platform's configuration. Never commit a credential, API key, or connection string accepted by a deployable application; deterministic synthetic credentials may live in isolated test fixtures.

## Logging

Use `ILogger<T>` with message templates, placing the log at the decision or failure point. Describe the operation and outcome, pass contextual values as template arguments, and pass a caught exception to the overload that accepts it.

```csharp
_logger.LogError(
    exception,
    "Failed to deliver order {OrderNumber} to facility {FacilityCode}.",
    orderNumber,
    facilityCode);
```

Levels: `Debug`/`Trace` for diagnostics; `Information` for meaningful lifecycle, integration, or business events; `Warning` for recoverable anomalies and operationally relevant expected failures; `Error` for an unexpected operation failure; `Critical` for application-threatening failure. Expected validation failures and ordinary business rejections are not errors. Routine entry/exit, database queries, and HTTP calls go unlogged; framework instrumentation covers them.

Attach correlation IDs, request identifiers, and tenant context through scopes or enrichment; add operation-specific identifiers only when relevant and not already ambient. Credentials, tokens, keys, and personal or sensitive payloads are never logged, and request or response bodies stay out by default. Audit history is durable business evidence stored as data, not a log.

Log inline. Reserve source-generated `LoggerMessage` methods for measured high-volume paths or messages reused across call sites, and set CA1848 to `none` so the analyzer does not demand them everywhere.

## Metrics and tracing

Add a custom metric only when it answers a named operational question standard instrumentation cannot, such as a business failure rate or the size and age of a delivery backlog, and when it backs an alert, health check, capacity decision, or recurring query. Keep metric attributes low-cardinality.
