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
| `ThrowError`, `AddError` + `ThrowIfAnyErrors` for business, not-found, or conflict outcomes | Return a result from domain or handler code and send the shared `ToProblem(HttpContext)` mapping ([error results](#error-results)); a request field's failure found in the handler takes the [validation flow](#handler-side-field-failures) instead |
| Command bus (`ICommand`, `ExecuteAsync`) and event bus (`IEvent`, `PublishAsync`) | Direct handler injection, unless the evidence bar in [architecture](architecture.md#transport-independent-operations) is met |
| Endpoint mappers (`Endpoint<TRequest, TResponse, TMapper>`) | Explicit private mapping methods in the endpoint or a focused mapper in the slice |
| `UseDefaultExceptionHandler()` | The shared `IExceptionHandler` that emits the common error format ([HTTP](http.md#error-responses)) |

Pass the `HandleAsync` cancellation token to every cancellable call. Send responses through `Send.*`, and expected-error results through `await Send.ResultAsync(errors.ToProblem(HttpContext))`.

A slice in `Features/Foos/CreateFoo/`, one file per type:

```csharp
// CreateFooRequest.cs
internal sealed record CreateFooRequest
{
    public string? Code { get; init; }
}

// CreateFooResponse.cs
internal sealed record CreateFooResponse(Guid Id);

// CreateFooValidator.cs
internal sealed class CreateFooValidator : Validator<CreateFooRequest>
{
    public CreateFooValidator()
    {
        RuleFor(x => x.Code).NotEmpty().WithErrorCode("Foo.CodeRequired");
    }
}

// CreateFooEndpoint.cs
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
            await Send.ResultAsync(foo.Errors.ForField(nameof(CreateFooRequest.Code)).ToProblem(HttpContext));
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

`Validator<TRequest>` instances are singletons: inject only singleton-safe dependencies, keep them to transport rules, and never `Resolve<T>()` scoped services. Give every rule a stable code with `WithErrorCode`. Request validation failures use the framework's own error flow: it short-circuits before `HandleAsync` with the [validation status](http.md#error-responses), in the shared error format. Field failures the endpoint finds itself take the same flow.

## Handler-side field failures

A request value can prove invalid only through I/O a validator must not do, such as a body reference that does not resolve ([domain](domain.md#expected-failures)). Report it against its field through the validation flow, so it shares the validator's status and format:

```csharp
var branch = await _branchDirectory.GetActiveAsync(branchCode, ct);
if (branch.IsError)
    ThrowError(r => r.BranchCode, branch.FirstError.Description, branch.FirstError.Code);
```

Only a `Validation` error takes this path. When a shared lookup reports the reference as `NotFound`, the caller re-catalogs it as its own `Validation` error first, because `ForField` keeps the error's type and `ToProblem` would send it as `404`. `ThrowError` is `[DoesNotReturn]`, so nullable analysis continues past it. With several independent field checks, call `AddError` for each and then `ThrowIfAnyErrors()`, so the caller sees every invalid field at once. An extracted handler cannot throw into the endpoint; it returns the error with [`ForField`](architecture.md#transport-independent-operations), and the endpoint sends it through `ToProblem`.

## Error results

Build the shared `ToProblem` on `FastEndpoints.ProblemDetails`, so validator failures, handler results, the exception handler, and status pages share one formatter and its configured transformers:

```csharp
internal static class ProblemExtensions
{
    private const string GeneralErrorsField = "GeneralErrors";

    public static IResult ToProblem(this IReadOnlyList<Error> errors, HttpContext context, int? statusCode = null)
    {
        var problem = new ProblemDetails(errors.Select(ToFailure).ToList(), statusCode ?? StatusFor(errors[0].Type))
        {
            Instance = context.Request.Path,
            TraceId = context.TraceIdentifier,
        };
        return TypedResults.Json(problem, statusCode: problem.Status, contentType: "application/problem+json");
    }

    public static IResult ToProblem(this Error error, HttpContext context, int? statusCode = null) =>
        new[] { error }.ToProblem(context, statusCode);

    private static ValidationFailure ToFailure(Error error) =>
        new(error.Metadata?.TryGetValue("name", out var name) == true ? (string)name : GeneralErrorsField, error.Description)
        {
            ErrorCode = error.Code,
        };

    private static int? StatusFor(ErrorType type) => type switch
    {
        ErrorType.Validation => null,
        ErrorType.Unauthorized => StatusCodes.Status401Unauthorized,
        ErrorType.Forbidden => StatusCodes.Status403Forbidden,
        ErrorType.NotFound => StatusCodes.Status404NotFound,
        ErrorType.Conflict => StatusCodes.Status409Conflict,
        ErrorType.Failure => StatusCodes.Status422UnprocessableEntity,
        _ => StatusCodes.Status500InternalServerError,
    };
}
```

A `null` status applies the configured `Errors.StatusCode`, and `GeneralErrorsField` repeats the framework's default, because both getters are internal. Wrap the result in `TypedResults.Json` as shown: a `ProblemDetails` returned directly as an `IResult` is sent as `application/json`.

The exception handler and status pages send the same result:

```csharp
// IExceptionHandler.TryHandleAsync, after logging once
await GeneralErrors.Unexpected.ToProblem(context).ExecuteAsync(context);

// Program.cs
app.UseStatusCodePages(pages =>
{
    var context = pages.HttpContext;
    var error = context.Response.StatusCode switch
    {
        StatusCodes.Status404NotFound => GeneralErrors.RouteNotFound,
        StatusCodes.Status405MethodNotAllowed => GeneralErrors.MethodNotAllowed,
        _ => GeneralErrors.RequestFailed,
    };
    return error.ToProblem(context, context.Response.StatusCode).ExecuteAsync(context);
});
```

## Configuration

- For the default error format, configure error responses so validation failures emit it with each error's `code` and the RFC 9110 `type` and `title` (FastEndpoints defaults to an RFC 7231 link and "Bad Request"; `TypeValue`/`TitleValue` do not override them, the transformers do):

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
