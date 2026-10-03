# Wolverine conventions

## Role

Wolverine is the default for durable asynchronous work: durable local queues, scheduled retries, and the transactional outbox within one process, and broker transport such as RabbitMQ across processes. Do not add polling workers, a job scheduler such as Hangfire or Quartz, or a hand-rolled outbox for the same need beside it. Introduce a broker only when delivery crosses independently deployed services, an event needs several independent consumers, or a platform standard requires one; scheduling work within one process does not.

An in-process synchronous call injects its handler directly ([architecture](architecture.md#transport-independent-operations)). A repository whose ADR adopts `IMessageBus.InvokeAsync` for in-process dispatch follows that decision.

Wolverine stays at the edges. Domain types, ports, adapters, and persistence entities never reference it; only handlers, the publishing code, and `Infrastructure/Messaging` registration do.

## Messages

Name a message for one unit of work, such as `DeliverLaboratoryOrderCommand`, and keep it beside the feature that handles it. A message carries identity and intent (a record ID or business key) rather than a snapshot of the data; the handler loads current state, so a delayed or repeated message never acts on stale data. Include source data only when an audit or immutability requirement demands it.

A message that crosses a language or deployable boundary is a wire contract: document its queue or routing key, JSON shape, versioning, and idempotency key beside the receiving feature, in a neutral form such as a JSON schema, rather than sharing a contracts assembly.

## Handlers

Wolverine compiles generated code against handlers, so handlers, messages, and every type in their public signatures are `public` ([C#](csharp.md#types-and-visibility)). A handler is a `public sealed` `*CommandHandler` with constructor-injected dependencies and one `Handle(TMessage, CancellationToken)` method.

Make every handler idempotent through business state. It loads its record once and finishes without external I/O when the record is no longer pending, which absorbs duplicates, obsolete messages, and redelivery after a crash. The durable inbox and Wolverine's message deduplication harden infrastructure; neither replaces that check, and deduplication suppresses a legitimate reschedule that reuses the same identity.

Around an external call:

1. Commit everything an unambiguous retry needs first: the claimed attempt and the exact request to send.
2. Make the call with no database transaction open.
3. Record the classified outcome. The adapter classifies its own results as succeeded, transient, configuration, or permanent ([HTTP](http.md#outbound-clients)), so the handler has one path per outcome and never infers a retry from an error code.

A transient outcome schedules the next attempt atomically with the recorded state. Retry budgets and backoff are business state on the record, not Wolverine policies. Unexpected exceptions escape to Wolverine.

## Outbox

Enroll each publishing `DbContext` in Wolverine's EF Core transactions (`UseEntityFrameworkCoreTransactions()` with the provider's `PersistMessagesWith*` store), and publish through `IDbContextOutbox<TDbContext>`. Endpoints and handlers call `PublishAsync` or `ScheduleAsync` on the outbox, then `SaveChangesAndFlushMessagesAsync`, so the state change and the message commit together. Publishing through `IMessageBus` after `SaveChangesAsync` loses the message if the process stops between the two.

An inbound webhook or intake endpoint persists the work and its message through the outbox before it acknowledges; the acknowledgement never rests on a fire-and-forget publish.

The message store's tables follow the application's migration path, never runtime creation: set `AutoBuildMessageStorageOnStartup = AutoCreate.None`, plus the store's own auto-create override where its provider has one, and apply Wolverine's schema through the same reviewed migration or deployment step ([persistence](persistence.md#migrations)).

## Queues and failures

Route each workload to its own durable local queue (`PublishMessage<T>().ToLocalQueue(name)` with `UseDurableInbox()`) so one integration's backlog never consumes another's capacity. Set `MaximumParallelMessages(1)` when concurrent messages for one identity would race and nothing else guards them, and record that reason; raise parallelism only with a replacement guard, such as a conditional update or concurrency token.

Configure error policies once in the host. Retry `DbUpdateConcurrencyException` with a short cooldown, so the retried handler reloads the record and its pending check absorbs the race. Give other exceptions a bounded `RetryWithCooldown` before dead-lettering. A dead-lettered message must stay recoverable through an operator path, such as a requeue endpoint that republishes the identity message.

## Composition and code generation

The host owns the single `AddWolverine` runtime and message store. In a [modular solution](architecture.md#modular-solutions) each module contributes its discovery, routes, and queues through `services.ConfigureWolverine(...)` with `Discovery.IncludeAssembly`.

Wolverine 6 rejects at startup a handler dependency registered through a factory lambda, which includes every typed `HttpClient`, because generated code cannot construct it. Prefer a registration Wolverine can see through (`AddScoped<IFoo, Foo>()`); for a genuinely opaque one, allow service location for that type alone with `CodeGeneration.AlwaysUseServiceLocationFor<T>()` in the module that registers it. Runtime code generation (`TypeLoadMode.Dynamic` or `Auto`) requires the `WolverineFx.RuntimeCompilation` package; pre-generate with `codegen write` and `TypeLoadMode.Static` when cold start or image size matters.

## Testing

Unit-test a handler by calling `Handle` with real or fake collaborators. Integration tests run the host and wait on Wolverine's tracked sessions, `host.TrackActivity().Timeout(...).InvokeMessageAndWaitAsync(message)`, rather than delays ([testing](testing.md#asynchronous-and-database-tests)).
