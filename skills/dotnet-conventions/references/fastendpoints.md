# FastEndpoints conventions

FastEndpoints base classes offer convenience members that bypass conventions elsewhere in this skill. Use the framework for routing, binding, validation, and response sending, and keep the rest of the code on the shared conventions.

## Endpoint members

| FastEndpoints member | Use instead |
| --- | --- |
| `Logger` property | A constructor-injected `ILogger<TEndpoint>` in `_logger` ([application](application.md#logging)) |
| `Resolve<T>()`, `TryResolve<T>()`, `CreateScope()` | Constructor injection; service location stays out of endpoints |
| Property injection | Constructor injection with `private readonly` fields ([C#](csharp.md#constructors-and-dependencies)) |
| `Config` (`IConfiguration`) | A validated options class injected as `IOptions<T>` ([application](application.md#configuration-and-options)) |
| `Env` (`IWebHostEnvironment`) | An options value describing the behavior; environment checks belong in composition |
| `ThrowError`, `AddError` + `ThrowIfAnyErrors` for business or not-found outcomes | Return a result from domain or handler code and send the shared `ToProblem(HttpContext)` mapping ([HTTP](http.md#error-responses)) |
| Command bus (`ICommand`, `ExecuteAsync`) and event bus (`IEvent`, `PublishAsync`) | Direct handler injection, unless the evidence bar in [architecture](architecture.md#transport-independent-operations) is met |
| Endpoint mappers (`Endpoint<TRequest, TResponse, TMapper>`) | Explicit private mapping methods in the endpoint or a focused mapper in the slice |
| `UseDefaultExceptionHandler()` | The shared `IExceptionHandler` that emits the common error format ([HTTP](http.md#error-responses)) |

Pass the `HandleAsync` cancellation token to every cancellable call. Send responses through `Send.*`, and expected-error results through `await Send.ResultAsync(errors.ToProblem(HttpContext))`.

A small slice in one file, `Features/Foos/CreateFoo.cs`:

```csharp
internal sealed record CreateFooRequest
{
    public string? Code { get; init; }
}

internal sealed record CreateFooResponse(Guid Id);

internal sealed class CreateFooValidator : Validator<CreateFooRequest>
{
    public CreateFooValidator()
    {
        RuleFor(x => x.Code).NotEmpty().WithErrorCode("Foo.CodeRequired");
    }
}

internal sealed class CreateFooEndpoint : Endpoint<CreateFooRequest, CreateFooResponse>
{
    private readonly AppDbContext _db;
    private readonly ILogger<CreateFooEndpoint> _logger;

    public CreateFooEndpoint(AppDbContext db, ILogger<CreateFooEndpoint> logger)
    {
        _db = db;
        _logger = logger;
    }

    public override void Configure()
    {
        Post("/foos");
    }

    public override async Task HandleAsync(CreateFooRequest request, CancellationToken ct)
    {
        var foo = Foo.Create(request.Code!);
        if (foo.IsError)
        {
            await Send.ResultAsync(foo.Errors.ToProblem(HttpContext));
            return;
        }

        _db.Foos.Add(foo.Value);
        await _db.SaveChangesAsync(ct);
        _logger.LogInformation("Created foo {FooCode}", foo.Value.Code);

        await Send.CreatedAtAsync<GetFooEndpoint>(
            new { id = foo.Value.Id },
            new CreateFooResponse(foo.Value.Id.Value),
            cancellation: ct);
    }
}
```

## Validators

`Validator<TRequest>` instances are singletons: inject only singleton-safe dependencies, keep them to transport rules, and never `Resolve<T>()` scoped services. Give every rule a stable code with `WithErrorCode`. Request validation failures are the one place the framework's own error flow is used: it short-circuits to `400` before `HandleAsync`, in the shared error format.

## Configuration

- Configure error responses so validation failures emit the shared format with each error's `code` and the RFC 9110 `type` and `title` (FastEndpoints defaults to an RFC 7231 link and "Bad Request"; `TypeValue`/`TitleValue` do not override them, the transformers do):

  ```csharp
  app.UseFastEndpoints(c => c.Errors.UseProblemDetails(p =>
  {
      p.IndicateErrorCode = true;
      p.TypeTransformer = problem => ProblemTypes.TypeFor(problem.Status);
      p.TitleTransformer = problem => ProblemTypes.TitleFor(problem.Status);
  }));
  ```
- Endpoints are secure by default; public routes call `AllowAnonymous()` explicitly and protected ones declare their policies in `Configure()`.
- Endpoint auto-discovery is the framework's registration model and an accepted exception to explicit registration. In a modular solution, set `DisableAutoDiscovery` and list each enabled module's assembly so composition stays visible in `Program.cs`.
- Register `JsonStringEnumConverter` in `c.Serializer.Options`.
