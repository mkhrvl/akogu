# Persistence conventions (EF Core)

## Access

EF Core's `DbContext` already provides repository and unit-of-work behavior. Features use it directly for straightforward work; a generic or per-entity repository adds nothing. Introduce a repository only for meaningful semantics: aggregate loading, claim-and-lease, compare-and-swap, provider locking, or reusable atomic operations. Extract a query service when a read is complex, reused, or independently meaningful. Keep `IQueryable<T>` inside the component that composes and executes it.

Request-scoped endpoints inject the context and treat the request as the unit of work. Use `IDbContextFactory<T>` for work that needs independently owned contexts: Blazor components, hosted services, parallel queries, and execution-strategy retries. Register one pooled factory for those rather than a second independent context registration: with Aspire, call `AddPooledDbContextFactory<T>()` yourself, register the scoped context from that factory (`services.AddScoped(sp => sp.GetRequiredService<IDbContextFactory<T>>().CreateDbContext())`), and add Aspire's health checks, retries, and telemetry with `builder.EnrichSqlServerDbContext<T>()` (or the provider's `Enrich*` equivalent) instead of `AddSqlServerDbContext<T>()`.

## Queries

Read models project directly with no-tracking queries. Load aggregates with tracking only when calling behavior on them and saving. Compare value-converted properties as their value-object type inside LINQ, never through `.Value`. Use explicit `AsSplitQuery()` when loading several sibling collections, as a local choice rather than a global default; split reads of one aggregate need a consistent view (a snapshot transaction or the aggregate's write lock). Load a filtered subset explicitly rather than `Include()`-ing the whole navigation.

Raw SQL is for requirements LINQ cannot express safely, such as `FOR UPDATE`, `SKIP LOCKED`, or `UPDLOCK`. It lives in `Infrastructure` behind a port and uses parameterized `FromSql(...)`.

## Saving and transactions

The use case owns the consistency boundary. Make the related changes, dependent records, and outbox messages, then call `SaveChangesAsync()` once near the end; the provider wraps that single save in a transaction. Repositories never save or commit on their own. When a durable messaging framework such as Wolverine or MassTransit owns the transaction and outbox, follow its unit-of-work and outbox model instead of hand-rolling one.

Add an explicit transaction only for multiple atomic save phases, mixed EF and direct SQL, a specific isolation level, or another defined atomic workflow. Keep it short and free of HTTP calls, file storage, or other external I/O; when resources cannot share a transaction, use an outbox, idempotency, durable retry, or reconciliation.

When the provider has retries enabled (Aspire database integrations enable them by default), run every explicit transaction through `Database.CreateExecutionStrategy()` so the whole transaction replays as one unit. Create the working context inside the strategy callback, load entities and begin the transaction there, and capture nothing tracked from outside it. Precompute only the IDs and instants that must stay stable across attempts. When the operation must distinguish an uncertain commit from a failed one, use the strategy's verification overload.

## Integrity and concurrency

The database is the final consistency boundary across concurrent requests, workers, scripts, and other applications. Enforce important integrity with unique indexes, foreign keys, non-null columns, check constraints, and suitable column types; domain validation gives early feedback on top. Translate an anticipated violation into an expected error only when the use case can identify it reliably, and keep provider exceptions out of API and domain code.

Add optimistic concurrency where concurrent updates could lose meaningful data, overwrite intent, or violate transitions; skip it for append-only, immutable, rebuildable, or intentional last-write-wins data. Translate `DbUpdateConcurrencyException` at the application boundary into a conflict, stale-state result, or a retry after reload and re-evaluation. Prefer an atomic conditional update for contention-heavy claim rules.

## Mapping

Map each entity in a dedicated `IEntityTypeConfiguration<T>` beside its `DbContext`, and keep `OnModelCreating` to applying configurations and cross-cutting conventions. Use the Fluent API rather than persistence attributes on domain types. Map single-value domain types with value converters. Give every `decimal` column explicit precision and scale. Choose one table and column naming convention for the whole database and apply it globally.

## Migrations

Generate migrations from model changes and commit each with the model snapshot. Several contexts sharing one database each keep their migrations in their own assembly or folder and set a distinct `MigrationsHistoryTable`. Review them as deployment artifacts: `Up()`, `Down()`, and the generated SQL for destructive changes, renames, required columns, defaults and backfills, constraints, indexes, and locking.

Edit `Up()`/`Down()` of a migration that has not been applied anywhere when EF cannot infer the intent: a data backfill, a rename scaffolded as drop-and-add, or provider-specific SQL. The designer file and model snapshot stay generated. Correct a deployed migration with a new one; to redo an unapplied one, `migrations remove`, fix the model, and scaffold again.

Development applies migrations through the MigrationService (see [project setup](project-setup.md)). Production applies a reviewed idempotent script in a controlled deployment step, never at application startup.
