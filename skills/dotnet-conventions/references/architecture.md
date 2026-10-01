# Architecture conventions

## Vertical slices

Organize application code by vertical slice: keep an operation's endpoint or handler, contracts, validation, mapping, and operation-specific collaborators together under `Features/<Area>/<Operation>`. Larger areas may group related operations under `Features/<Area>/<Capability>/<Operation>`; in a [modular solution](#modular-solutions) the module is the area. Give shared domain, infrastructure, and cross-cutting concerns their own roots (`Domain`, `Infrastructure`) only when they serve several features. Add subfolders when they make related work easier to find and new files easier to place; file count alone does not justify nesting, and roots need not mirror each other's trees.

Name operation folders and types with verbs: `Create` for a new independently identifiable entity, `Update` for ordinary maintenance, a precise verb for a state transition (`Approve`, `Deactivate`), and `Add` only for a member or association. Integration and messaging slices name the flow and its direction instead: `Send` for a caller-initiated request passed on to another system, `Receive` for an inbound callback, `Deliver` for background fulfillment of persisted work. Keep each lifecycle transition its own slice even when one screen presents them together.

Keep Commands, Queries, Results, and HTTP contracts with their owning operation. Collect nothing into generic `Application`, `Contracts`, `Services`, or `Helpers` roots; within a feature, group helpers by responsibility (`Reporting`, `ExpiryReminders`). A `Services` folder needs a precise membership rule beyond "classes that do work".

## Slice files

Each operation is a folder, such as `Features/Foos/CreateFoo/`, holding one same-named file per type: `CreateFooEndpoint.cs`, `CreateFooRequest.cs`, `CreateFooValidator.cs`, `CreateFooResponse.cs` (or the command, validator, result, and handler). Types that [share a file](csharp.md#types-and-visibility) by exception stay with their primary type.

## Endpoints as handlers

An endpoint whose operation has one production caller is that operation's handler. It holds the workflow as a visible sequence (receive input, load state, call domain or integration behavior, persist, map the result) and delegates focused domain, infrastructure, or reusable work; a cohesive endpoint has no line limit. Keep business rules in domain types, where unit tests cover them cheaply, so the endpoint is orchestration that integration tests exercise once per path. Such an endpoint always has a request validator for transport shape; field checks that need I/O run in the endpoint's workflow ([FastEndpoints](fastendpoints.md#handler-side-field-failures)).

Extract a transport-independent operation only when a second production caller needs it: a UI such as Blazor, a worker, a consumer, a CLI, or another endpoint, in this host or another. Tests and file length do not earn that boundary. After extraction the endpoint keeps binding, authorization, HTTP errors, headers, streaming, and response shaping, and calls the handler.

## Transport-independent operations

Names follow the transport. HTTP contracts are `*Request` and `*Response`; transport-independent contracts are `*Command` or `*Query`, `*CommandHandler` or `*QueryHandler`, `*CommandValidator`, and `*Result`: `CreateFooCommand`, `CreateFooCommandHandler`, `CreateFooCommandValidator`, `CreateFooResult`. A handler never receives a `*Request` or returns a `*Response`; the endpoint maps between them. Commands, Queries, and Results carry no HTTP statuses, headers, ProblemDetails, or public API types.

A handler is a concrete `internal sealed` class with one method, `HandleAsync(TCommand command, CancellationToken cancellationToken)`, injected directly into its callers. Give it an interface only for the reasons in [application](application.md#composition-and-dependency-injection), never a generic `ICommandHandler<T>`. An input-free handler accepts only `CancellationToken`; do not create empty marker Commands or Queries.

Return types:

- `ErrorOr<CreateFooResult>` when the caller needs data back, such as a new identifier.
- `ErrorOr<Success>` for a write with nothing to return.
- `ErrorOr<FooDetails>` for a query that can fail, such as not found; a plain value when it cannot.

The handler validates its own input, because with no pipeline nothing else guarantees every caller does. It injects `IValidator<TCommand>`, validates before any other work, and returns failures as `Error.Validation` entries carrying the rule's stable code and the property name (see [error codes](domain.md#error-catalogs)). The endpoint's request validator checks only HTTP request shape; omit it when the request maps one-to-one onto the Command, so the same rules do not run twice.

```csharp
internal sealed class CreateFooCommandHandler
{
    private readonly IValidator<CreateFooCommand> _validator;
    private readonly AppDbContext _db;

    public CreateFooCommandHandler(IValidator<CreateFooCommand> validator, AppDbContext db)
    {
        _validator = validator;
        _db = db;
    }

    public async Task<ErrorOr<CreateFooResult>> HandleAsync(
        CreateFooCommand command,
        CancellationToken cancellationToken)
    {
        var validation = await _validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
            return validation.Errors.ToValidationErrors();

        var foo = Foo.Create(command.Code);
        if (foo.IsError)
            return foo.Errors.ForField(nameof(CreateFooCommand.Code));

        _db.Foos.Add(foo.Value);
        await _db.SaveChangesAsync(cancellationToken);

        return new CreateFooResult(foo.Value.Id);
    }
}
```

`ToValidationErrors()` is one shared extension that maps each `ValidationFailure` to `Error.Validation(failure.ErrorCode, failure.ErrorMessage, new Dictionary<string, object> { ["name"] = failure.PropertyName })`.

A handler that finds a Command value invalid only through I/O, such as a reference that does not resolve, returns that error carrying the field's `name` too: `branch.Errors.ForField(nameof(CreateFooCommand.BranchCode))`. `ForField(name)` is the companion extension beside `ToValidationErrors()`; it rebuilds each error with `Error.Custom((int)error.Type, error.Code, error.Description, metadata)`, because ErrorOr errors are immutable. Errors a value factory returns, such as `Foo.Create(command.Code)`, carry the field's `name` the same way. Handlers name Command properties; where a Request property maps to a differently named Command property, the endpoint renames the error's `name` before sending it.

Workers and consumers follow the same shape: create a scope per unit of work, build the Command, call the handler, and log the result where the flow decides what happens next.

A mediator, dispatcher, generic decorator pipeline, event bus, or assembly scanner earns its place only with evidence: runtime dispatch is needed, the same cross-cutting behavior is duplicated across three or more handlers, registrations are repeatedly missed, or one business occurrence has several independent side effects.

## Ports

A **port** is an application-owned interface for an external or framework capability, such as `IEmailSender` or `IFooClient`. It lives in the consuming feature, beside the narrow request, result, and error types it exposes; group several under a local `Ports/` folder. Its adapter lives in `Infrastructure`. An `I` prefix alone does not make an interface a port.

Shape a port around the capability its callers need, not around the adapter class. One adapter may implement several related ports; keep the ports separate so a caller gains only the capability it asked for.

## Dependency direction

`Features` do not depend on `Infrastructure`; `Infrastructure` depends on `Features` to implement their ports and owns their registration. `Domain` depends on nothing application-specific.

The EF Core `DbContext` is the one named exception: it lives with its configurations and migrations in `Infrastructure/Data` or a top-level `Data` root, and features use it directly as their persistence interface. Provider-specific APIs, raw SQL, direct connections, and provider exception interpretation stay in `Infrastructure` behind a port. Enforce these rules, including the `DbContext` exception, with architecture tests.

## Modular solutions

A modular solution splits the application into module projects, each owning one external system or business boundary, composed by a host. The module supplies the area, so slices sit directly at `Features/<Operation>` inside each module. Each module owns its `DbContext` in its own `Data` root, with migrations kept per module as in [persistence](persistence.md#migrations), and features use only their own module's context. Architecture tests enforce the dependency rules per module, using the module's `Data` namespace as the persistence boundary. With FastEndpoints, compose modules explicitly as in [FastEndpoints](fastendpoints.md#configuration).
