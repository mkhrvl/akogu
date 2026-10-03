# Project setup

The baseline for a new solution. In an existing repository, compare against it and propose the missing pieces one at a time.

## Layout

```text
<Name>.slnx
global.json
Directory.Build.props
Directory.Packages.props
.editorconfig
.csharpierignore
.config/dotnet-tools.json
.husky/                              # pre-commit formatting
scripts/verify.sh                    # the local mirror of the CI build stage
scripts/outdated.sh
src/<Name>.AppHost/                  # Aspire local orchestration
src/<Name>.ServiceDefaults/          # health checks, OpenTelemetry, service discovery
src/<Name>.MigrationService/         # only with EF Core code-first
src/<Name>.<App>/                    # Web, Api, Worker, ...
tests/<Name>.Tests.Unit/
tests/<Name>.Tests.Integration/
tests/<Name>.Tests.Architecture/
```

Use the `.slnx` solution format. Start with one application project organized by vertical slices; add projects for deployable units, modules with a real ownership boundary, or code that must be shared, not for layers.

## Build configuration

`global.json` sets the minimum SDK and the test runner. CI installs the SDK from this file (for example `actions/setup-dotnet` with `global-json-file`), so local and CI builds use the same feature band:

```json
{
  "sdk": { "version": "<current SDK>", "rollForward": "latestFeature", "allowPrerelease": false },
  "test": { "runner": "Microsoft.Testing.Platform" }
}
```

`Directory.Build.props` applies to every project:

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
  </PropertyGroup>
</Project>
```

`Directory.Packages.props` sets `<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>` and holds every package version. It also sets `<CentralPackageTransitivePinningEnabled>true</CentralPackageTransitivePinningEnabled>`, so a `PackageVersion` entry lifts a vulnerable transitive package that NuGet audit flags without adding a direct reference. NuGet auditing of direct and transitive packages is on by default for `net10.0`.

When `nuget.config` lists more than one package source, add `<packageSourceMapping>` so each package ID pattern resolves from exactly one source (private prefixes to the private feed, `*` to nuget.org).

Warnings stay warnings locally so work in progress builds, and fail in CI: `scripts/verify.sh` and the CI build pass `-p:TreatWarningsAsErrors=true` to the build that performs the restore, so NuGet audit warnings fail too. `.editorconfig` severities decide what counts: `suggestion` never fails, `warning` fails CI. A newly published advisory then fails CI until the package is updated.

## Analyzers and licenses

The built-in .NET analyzers (`AnalysisLevel` above) are the baseline. Add a third-party analyzer package only when its license permits commercial use and AI coding agents reading its diagnostics. Do not add `SonarAnalyzer.CSharp` to new projects: the SONAR Source-Available License excludes AI tools ingesting or interpreting its output. Keep it where a project already has it, and use Sonar's own MCP server for agent access to Sonar analysis.

Check the license of every new package or tool before adding it. Known commercial-license traps: FluentAssertions 8+, MediatR and AutoMapper (commercial since 2025), and MassTransit 9+.

## `.editorconfig`

Start from this and add rules only when a convention is mechanically checkable. Naming-rule severities apply only in the IDE; `IDE1006` makes them fail the build.

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 4

[*.{json,yml,yaml,props,targets,csproj,slnx}]
indent_size = 2

[*.cs]
csharp_style_namespace_declarations = file_scoped:warning
csharp_style_prefer_primary_constructors = false:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_for_built_in_types = false:suggestion
csharp_style_var_elsewhere = false:suggestion
dotnet_style_require_accessibility_modifiers = for_non_interface_members:warning
dotnet_diagnostic.IDE0051.severity = warning
dotnet_diagnostic.IDE0052.severity = warning
dotnet_diagnostic.IDE0059.severity = warning
dotnet_diagnostic.IDE1006.severity = warning
dotnet_diagnostic.CA1848.severity = none
dotnet_diagnostic.CA1852.severity = warning
dotnet_code_quality.CA1852.ignore_internalsvisibleto = true
dotnet_diagnostic.CA2016.severity = warning

dotnet_naming_style.pascal.capitalization = pascal_case
dotnet_naming_style.underscore_camel.required_prefix = _
dotnet_naming_style.underscore_camel.capitalization = camel_case
dotnet_naming_style.async_suffix.required_suffix = Async
dotnet_naming_style.async_suffix.capitalization = pascal_case

dotnet_naming_symbols.private_constants.applicable_kinds = field
dotnet_naming_symbols.private_constants.applicable_accessibilities = private
dotnet_naming_symbols.private_constants.required_modifiers = const
dotnet_naming_rule.private_constants_pascal.symbols = private_constants
dotnet_naming_rule.private_constants_pascal.style = pascal
dotnet_naming_rule.private_constants_pascal.severity = warning

dotnet_naming_symbols.private_fields.applicable_kinds = field
dotnet_naming_symbols.private_fields.applicable_accessibilities = private
dotnet_naming_rule.private_fields_underscore.symbols = private_fields
dotnet_naming_rule.private_fields_underscore.style = underscore_camel
dotnet_naming_rule.private_fields_underscore.severity = warning

dotnet_naming_symbols.async_methods.applicable_kinds = method
dotnet_naming_symbols.async_methods.required_modifiers = async
dotnet_naming_rule.async_methods_suffix.symbols = async_methods
dotnet_naming_rule.async_methods_suffix.style = async_suffix
dotnet_naming_rule.async_methods_suffix.severity = warning

[tests/**/*.cs]
dotnet_diagnostic.CA1707.severity = none
dotnet_naming_rule.async_methods_suffix.severity = none

[**/Migrations/*.Designer.cs]
generated_code = true

[**/Migrations/*ModelSnapshot.cs]
generated_code = true
```

CA1852 enforces the `internal sealed` default; it is off by default and skips any assembly with `InternalsVisibleTo`, which test access requires, unless `ignore_internalsvisibleto` is set. CA2016 enforces passing the caller's cancellation token. The private-constant rule is more specific than the private-field rule, so it takes precedence; private `static readonly` fields follow the `_camelCase` field rule. Migration classes themselves stay analyzer-visible because they may carry hand-written backfills and SQL.

## Local tools

Pin tools in a local manifest at `.config/dotnet-tools.json` (`dotnet new tool-manifest -o .config`; without `-o`, .NET 10 writes it to the repository root) so every clone and CI run uses the same versions; `dotnet tool restore` installs them.

| Tool | Package | Use |
| --- | --- | --- |
| CSharpier | `csharpier` | The only C# formatter: `dotnet csharpier format <paths>` after edits, `dotnet csharpier check .` in CI. `.csharpierignore` excludes migrations and generated code. |
| Husky.Net | `husky` | Git hooks. Run `dotnet husky install` once per clone. |
| dotnet-outdated | `dotnet-outdated-tool` | `scripts/outdated.sh` runs `dotnet outdated --recursive` to report stale packages for a deliberate update pass. |
| Aspire CLI | `aspire.cli` | Creates, runs, and inspects the AppHost (`aspire start`, `aspire ps`); see the `aspire` skill. |
| EF Core CLI | `dotnet-ef` | Only with EF Core: scaffolds migrations and generates deployment scripts. |

The Husky pre-commit task formats staged C# files as a safety net; formatting still happens during the work, before review.

`.husky/task-runner.json`:

```json
{
  "$schema": "https://alirezanet.github.io/Husky.Net/schema.json",
  "tasks": [
    {
      "name": "csharpier-format",
      "group": "pre-commit",
      "command": "dotnet",
      "args": ["csharpier", "format", "${staged}"],
      "include": ["**/*.cs"]
    }
  ]
}
```

`.husky/pre-commit`:

```sh
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"
dotnet husky run --group pre-commit
```

Sourcing `_/husky.sh` makes `HUSKY=0` skip hooks (for CI or emergencies) and loads `~/.huskyrc` for GUI git clients.

## `scripts/verify.sh`

Runs what the CI build stage runs, in `Release`. List only the test projects that exist, and add each new one:

```sh
#!/usr/bin/env sh
set -eu
dotnet tool restore
dotnet csharpier check .
dotnet build <Name>.slnx -c Release -p:TreatWarningsAsErrors=true
dotnet test --project tests/<Name>.Tests.Unit/<Name>.Tests.Unit.csproj -c Release --no-build
dotnet test --project tests/<Name>.Tests.Architecture/<Name>.Tests.Architecture.csproj -c Release --no-build
```

Integration tests need Docker and run from a separate script and CI stage. When deployment consumes published output, CI also runs `dotnet publish -c Release` for each deployable project.

## Aspire AppHost and ServiceDefaults

Local development runs through an Aspire AppHost that owns the resource graph: the application, databases, caches, queues, and local stand-ins such as a mail catcher. Scaffold with `aspire new` or `aspire init` (see the `aspire-init` skill); run with `aspire start`, never `dotnet run` on the AppHost. Every service project calls `builder.AddServiceDefaults()` for health checks, OpenTelemetry, and service discovery. Remove the template's `AddStandardResilienceHandler()` from `ConfigureHttpClientDefaults` and configure resilience per client, and map health endpoints for deployment as described in [HTTP](http.md#production-boundary).

Keep local-only settings in AppHost configuration and user secrets. The AppHost passes values to projects through resource references and environment variables rather than reading their `appsettings` files.

## MigrationService

With EF Core code-first, add a worker project that applies migrations and exits. The AppHost starts the application only after it completes successfully, so the application never migrates at startup:

```csharp
var database = builder.AddSqlServer("sql").AddDatabase("app");

var migrations = builder.AddProject<Projects.Foo_MigrationService>("migrations")
    .WithReference(database)
    .WaitFor(database);

builder.AddProject<Projects.Foo_Web>("web")
    .WithReference(database)
    .WaitForCompletion(migrations);
```

`WaitForCompletion` requires exit code 0. Through .NET 10 an exception thrown from a `BackgroundService` still exits with 0, and this worker catches its failure to log it, so it sets a non-zero exit code itself:

```csharp
public sealed class MigrationWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IHostApplicationLifetime _lifetime;
    private readonly ILogger<MigrationWorker> _logger;

    public MigrationWorker(
        IServiceScopeFactory scopeFactory,
        IHostApplicationLifetime lifetime,
        ILogger<MigrationWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _lifetime = lifetime;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await using var scope = _scopeFactory.CreateAsyncScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            await db.Database.MigrateAsync(stoppingToken);
            _logger.LogInformation("Database migrations applied");
        }
        catch (Exception exception) when (!stoppingToken.IsCancellationRequested)
        {
            _logger.LogCritical(exception, "Database migration failed");
            Environment.ExitCode = 1;
        }
        finally
        {
            _lifetime.StopApplication();
        }
    }
}
```

Its `Program.cs` registers the context through the Aspire client integration (for example `builder.AddSqlServerDbContext<AppDbContext>("app")`) and the worker. With several contexts, the worker migrates each in turn, typically through one migrator per module resolved from DI. Production does not run the MigrationService: generate a reviewed idempotent script with `dotnet ef migrations script --idempotent` and apply it in a controlled deployment step.

## Repository guidance

Create `AGENTS.md` with a pointer to this skill for C# work, copy the skill into `.agents/skills/` so every agent working in the repository has it, and record only project-specific decisions in `docs/guides/` and ADRs. List each deliberate deviation from this skill in the guide `AGENTS.md` points to, citing its ADR, so agents treat it as settled.
