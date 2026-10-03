# Dapper conventions

## When to use it

EF Core stays the default for table-backed reads and writes. Use Dapper for stored procedures, multiple result sets, output parameters, reports, legacy result shapes, and set-based SQL that LINQ expresses poorly or translates inefficiently. Choose by data movement and round trips rather than the tool: keep work in SQL when it filters, joins, aggregates, or mutates data close to the database, and keep workflow orchestration and validation in application code.

Dapper code is raw SQL, so it lives in `Infrastructure` behind a port ([architecture](architecture.md#dependency-direction)). Group it in one data-access class per area. Materialize straight into the port's result type when its properties match the result columns one-to-one; otherwise read into a private row record and map explicitly, so a column rename never reaches application code.

## Connections

Beside EF Core, run Dapper on the context's connection through one shared helper: take `Database.GetDbConnection()`, open it only when it is closed, and close only a connection the helper opened. Dapper then shares the context's connection string, pooling, and interceptors.

Dapper does not enlist in an EF Core transaction on its own. Inside one, pass `transaction: dbContext.Database.CurrentTransaction?.GetDbTransaction()` on every command; SqlClient rejects a command without it on a connection with a pending transaction. Under provider retries, run the whole unit through `Database.CreateExecutionStrategy()` as in [persistence](persistence.md#saving-and-transactions); a Dapper call outside the strategy is not retried.

Without EF Core, register the provider's client once (an `NpgsqlDataSource`, or a factory over `SqlConnection`, through the Aspire client integration where one exists), and open a connection per operation with `await using`.

## Commands

Execute every command through `CommandDefinition` with `cancellationToken:`; Dapper's convenience overloads take no token, and CA2016 cannot see the gap. Call stored procedures by schema-qualified name with `commandType: CommandType.StoredProcedure`.

```csharp
var rows = await connection.QueryAsync<FooListRow>(
    new CommandDefinition(
        "dbo.usp_Foo_List_v2",
        new { query.Search, query.PageNumber, query.PageSize },
        commandType: CommandType.StoredProcedure,
        cancellationToken: cancellationToken));
```

Pass values as parameters: an anonymous object by default, `DynamicParameters` for output or return values and conditionally built parameter sets. Never concatenate values into SQL. Build dynamic SQL, such as a sort column or direction, only from an allowlist of known identifiers.

On SQL Server, Dapper sends strings as `nvarchar(4000)`. Against a `varchar` column in ad-hoc SQL that forces an implicit conversion and can bypass the column's index, so pass `new DbString { Value = code, IsAnsi = true, Length = 20 }` there. A stored procedure parameter's declared type governs the conversion instead.

Set `commandTimeout` only on a command with a measured need, from a named constant, rather than raising a global default.

## Results

Buffered queries are the default; return their list with `.AsList()` rather than copying it. Use `QueryUnbufferedAsync` only to stream a large result whose consumer owns the connection for the whole read. Read a `QueryMultipleAsync` grid in result-set order and dispose it before the connection closes.

Alias columns in SQL (`AS`) to match property names rather than adding custom type maps. For a snake_case database, set `DefaultTypeMap.MatchNamesWithUnderscores = true` once at startup. Register a `SqlMapper.TypeHandler<T>` for a value object once in composition; Dapper's maps are process-wide state.

## Procedures and schema

Version every procedure, view, or function the code calls with the schema: in an EF Core migration (`migrationBuilder.Sql`) for a code-first database, or in the repository's database project for a database-first one. When another application consumes a procedure, leave it unchanged and add a new procedure for the new contract, such as `usp_Foo_List_v2`, rather than branching the old one on a mode parameter.

Integration tests run each statement and procedure against the real provider ([testing](testing.md#projects-and-test-levels)); a mapping mistake compiles and fails only at runtime.
