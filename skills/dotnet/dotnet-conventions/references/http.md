# HTTP conventions

## Inbound endpoints

Follow the repository's established endpoint style: controllers, minimal APIs, or FastEndpoints. Mixing a second style into an existing API needs a deliberate decision, not a single change. When a new project has no API convention yet, suggest FastEndpoints and let the user choose. When the repository uses FastEndpoints, also read [FastEndpoints](fastendpoints.md).

Whatever the framework, keep each operation's `*Request`, `*Response`, and optional `*Validator` in its feature slice, laid out as in [slice files](architecture.md#slice-files), and omit contracts that do not exist. With minimal APIs, give each operation its own endpoint class or static handler in the slice; with controllers, keep actions thin adapters over the slice. Endpoint contracts are feature-specific; duplicate rather than share across independently evolving endpoints.

Give JSON request DTOs nullable properties without `required`, and let a FluentValidation validator own requiredness, so an omitted property and an explicit `null` take the same validation path. Document requiredness in OpenAPI independently of C# nullability: `Microsoft.AspNetCore.OpenApi` for controllers and minimal APIs, the FastEndpoints OpenAPI package in FastEndpoints repositories. Validators check transport rules; database or external I/O in a validator is reserved for a rule that genuinely belongs at the boundary.

Require authentication by default through a fallback authorization policy. Public routes, such as health probes, opt out explicitly with `AllowAnonymous()`. Implement API-key or custom credentials as ASP.NET Core authentication schemes so authorization sees a real principal. UI-level permission checks are for usability; the entry point enforces the policy.

## Error responses

Every error response, whether from a validator, a mapped `ErrorOr` result, or an unhandled exception, is RFC 9457 Problem Details (`application/problem+json`). The format below is the default for a new API, and every expected error in it carries a stable code. An established API keeps its own layout; recommend codes as an improvement rather than adding them unasked. The default adds `traceId` and an `errors` array as extension members. Each `errors` entry carries `name` (the field, or `generalErrors` for errors not tied to a field), `reason` (human-readable), and a stable `code` that clients react to instead of parsing messages or depending on property names. `detail` repeats the reason when there is exactly one error:

```json
{
  "type": "https://www.rfc-editor.org/rfc/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "instance": "/foos",
  "traceId": "0HMPNHL0JHL76:00000001",
  "detail": "Foo code must be 3 to 20 characters.",
  "errors": [
    { "name": "code", "reason": "Foo code must be 3 to 20 characters.", "code": "Foo.InvalidCode" }
  ]
}
```

`type` is the RFC 9110 section for the status and `title` its standard phrase, except validation responses, which use "One or more validation errors occurred."; both come from one shared `ProblemTypes` helper used by every path; a custom documented `type` URI is unnecessary because each error's `code` already distinguishes errors. FastEndpoints produces this format once configured as in [FastEndpoints](fastendpoints.md#configuration), and builds `ToProblem` on its own `ProblemDetails` ([error results](fastendpoints.md#error-results)). Controllers and minimal APIs emit the same wire format through an application-owned contract, never by depending on the FastEndpoints CLR type:

```csharp
internal sealed record ApiProblem
{
    public required string Type { get; init; }
    public required string Title { get; init; }
    public required int Status { get; init; }
    public required string Instance { get; init; }
    public required string TraceId { get; init; }
    public string? Detail { get; init; }
    public IReadOnlyList<ApiProblemError> Errors { get; init; } = [];
}

internal sealed record ApiProblemError(string Name, string Reason, string Code);
```

For controllers and minimal APIs, one shared `ToProblem(HttpContext)` extension maps `ErrorOr` errors to this contract: `Instance` from the request path, `TraceId` from `HttpContext.TraceIdentifier`, each error's `Name` from its `name` metadata with the first segment camelCased as FastEndpoints does (`generalErrors` when absent), and `Detail` when there is exactly one error. It returns `TypedResults.Json(problem, statusCode: problem.Status, contentType: "application/problem+json")`. FastEndpoints repositories use the [FastEndpoints implementation](fastendpoints.md#error-results); both follow the status mapping below. The first error's type decides the status unless the caller passes one:

| ErrorOr type | Status | `type` (RFC 9110) | `title` |
| --- | --- | --- | --- |
| `Validation` | Configured validation status: `400`, or `422` | `#section-15.5.1`, or `#section-15.5.21` | One or more validation errors occurred. |
| `Unauthorized` | `401` | `#section-15.5.2` | Unauthorized |
| `Forbidden` | `403` | `#section-15.5.4` | Forbidden |
| `NotFound` | `404` | `#section-15.5.5` | Not Found |
| `Conflict` | `409` | `#section-15.5.10` | Conflict |
| `Failure` | `422` | `#section-15.5.21` | Unprocessable Content |
| `Unexpected` and anything else | `500` | `#section-15.6.1` | Internal Server Error |

Each `type` is `https://www.rfc-editor.org/rfc/rfc9110` plus the section anchor. `ProblemTypes` covers every status the API sends, including `405` (`#section-15.5.6`, Method Not Allowed), `415` (`#section-15.5.16`, Unsupported Media Type), `502` (`#section-15.6.3`, Bad Gateway), `503` (`#section-15.6.4`, Service Unavailable), and `504` (`#section-15.6.5`, Gateway Timeout).

Validator failures and `Validation` results return the same status. `400` is the default. `422` (`#section-15.5.21`, Unprocessable Content) is an accepted variant that separates a body that cannot be read (binding, `400`) from readable but invalid content (`422`); it applies to both paths, which FastEndpoints configures with `c.Errors.StatusCode = StatusCodes.Status422UnprocessableEntity`. An externally dictated contract, such as an OAuth token endpoint (RFC 6749) or a vendor's callback specification, keeps the statuses it defines.

An operation that completes through a downstream call within the request maps the port's classified technical outcomes at the endpoint: an invalid or unexplained refusal is `502`, an unavailable system `503`, a timeout `504`; collapse them into `502` when callers react the same way. A downstream business rejection with a meaning the caller can act on maps like a local one (`Failure`, `Conflict`). Failures the adapter did not anticipate still propagate to the central handler. Send a cataloged error with the status passed explicitly, `FooErrors.NotAccepted.ToProblem(HttpContext, StatusCodes.Status502BadGateway)`, so the response keeps the shared format and a code.

Declare the contract as the error response schema in OpenAPI and document any non-obvious client-visible mapping. Item-level outcomes within a batch stay in a successful response body.

Framework-generated errors bypass `ToProblem` in controllers and minimal APIs. With `AddProblemDetails()` registered, a minimal API writes a malformed JSON body as `HttpValidationProblemDetails` (an `errors` dictionary) through `IProblemDetailsService`, and `[ApiController]` answers invalid model state through `ApiBehaviorOptions.InvalidModelStateResponseFactory`. Route both into the contract: register an `IProblemDetailsWriter` that converts the framework's `ProblemDetails` into `ApiProblem` before calling `AddProblemDetails()`, because the service uses the first registered writer that accepts, and set `InvalidModelStateResponseFactory` to return the same contract. Each converted entry becomes an error named by its key with code `General.InvalidRequest`. An integration test sends a malformed body to prove the format.

Handle unexpected failures centrally: `AddProblemDetails()`, `UseExceptionHandler()`, and an `IExceptionHandler` that logs once and sends `ToProblem` with status `500`, code `General.Unexpected`, and no exception details outside `Development`. Add `UseStatusCodePages()` sending bodiless responses, such as `404` and `405`, through `ToProblem` too, with `General.*` codes, so every error body has one shape.

## Production boundary

Apply each item when its trigger holds, and decide whether the application or the edge proxy owns it:

- **Behind a proxy or load balancer**: configure `ForwardedHeaders` with the known proxies or networks, before middleware that reads scheme or client IP.
- **HTTPS**: `UseHttpsRedirection()` and `UseHsts()` outside `Development`, unless the proxy terminates TLS and enforces them.
- **Browser clients from other origins**: a named CORS policy with an explicit origin allowlist; never allow any origin together with credentials.
- **Public or partner-facing APIs**: `AddRateLimiter()` with a partition per client or API key, and request body size limits sized to the largest legitimate payload.
- **Cookie authentication**: antiforgery on unsafe methods, and Data Protection keys persisted to shared storage when more than one instance runs or instances restart.
- **Browser-rendered responses**: security headers (`Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, frame restrictions).

Health endpoints: the ServiceDefaults template maps `/health` and `/alive` only in `Development`. For deployed probes, map liveness (process up, no dependency checks) and readiness (dependencies reachable) explicitly, call `AllowAnonymous()` on them because the fallback policy otherwise returns `401`, return status only without check details, and restrict exposure to the orchestrator's network or port.

## Outbound clients

Register each external system as a typed or named `HttpClient` through `IHttpClientFactory`. The consuming feature owns the port, its narrow contracts, and the options; the `Infrastructure` registration owns the adapter, `AddHttpClient`, base address, authentication handler, serializer settings, timeouts, and resilience. Keep unmanaged `HttpClient` construction out of application code.

Adapters expose narrow application-facing request and result types behind the port. `HttpResponseMessage`, wire DTOs, vendor errors, serializer attributes, and status interpretation stay inside the adapter. Translate anticipated remote outcomes into operation-specific cases (accepted, rejected, conflict, not found, rate limited, temporarily unavailable); let unexpected transport or protocol failures propagate, or wrap them in an application-neutral exception carrying the original and non-sensitive context.

Inspect statuses explicitly when the contract defines outcomes, including distinct successes such as `202` and `204`. `EnsureSuccessStatusCode()` fits only when every non-success is uniformly unexpected.

Each integration owns one configured System.Text.Json `JsonSerializerOptions` instance for its naming, enums, converters, and dates, reused and never mutated after first use. Map explicitly between wire DTOs and domain or application types; serializing domain entities or public API contracts straight to a vendor couples them to it.

Dispose every request, response, and stream an adapter creates. Buffered operations return mapped contracts; streaming transfers ownership through a focused disposable wrapper using `HttpCompletionOption.ResponseHeadersRead`, never a bare `Stream` or `HttpResponseMessage`.

## Resilience

Configure resilience on each named or typed `HttpClient`, not globally across all outbound clients. Use `AddStandardResilienceHandler()` as the default pipeline and disable retries for unsafe HTTP methods with `Retry.DisableForUnsafeHttpMethods()`. Read settings from validated options through the service provider:

```csharp
services.AddHttpClient<IFooClient, FooClient>((sp, client) =>
        client.BaseAddress = sp.GetRequiredService<IOptions<FooOptions>>().Value.BaseUrl)
    .AddStandardResilienceHandler()
    .Configure((resilience, sp) =>
    {
        var options = sp.GetRequiredService<IOptions<FooOptions>>().Value;
        resilience.Retry.DisableForUnsafeHttpMethods();
        resilience.AttemptTimeout.Timeout = options.AttemptTimeout;
        resilience.CircuitBreaker.SamplingDuration = options.CircuitBreakerSamplingDuration;
        resilience.TotalRequestTimeout.Timeout = options.TotalTimeout;
    });
```

The standard pipeline validates its options on first use: `CircuitBreaker.SamplingDuration` must be at least twice `AttemptTimeout`, and `TotalRequestTimeout` must exceed `AttemptTimeout`. Enforce the same relationships in the integration's options validator so a bad combination fails at startup, not on the first request.

Configure retry counts, attempt timeout, total timeout, circuit-breaker behavior, and concurrency limits per downstream dependency from its documented behavior, latency, SLA, and idempotency guarantees. Each integration earns its own values; copying another integration's timeouts or retry counts for consistency gives neither the right ones. Retry an unsafe method only when the downstream operation has an explicit idempotency guarantee, sending the same idempotency key on every attempt.

Treat a timeout or dropped connection as indeterminate: the remote side may have completed the operation. Longer recovery belongs in a durable outbox, queue, or scheduled retry that records attempts and outcomes. Cancellation and shutdown end retries rather than counting as transient failures.
