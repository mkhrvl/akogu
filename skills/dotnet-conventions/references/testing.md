# .NET testing conventions

## Stack

- xUnit v3 on Microsoft Testing Platform.
- AwesomeAssertions (Apache-2.0) where it improves failure messages; plain `Assert` for trivial checks.
- NSubstitute (BSD-3-Clause) when a mock is warranted. Mocking internal interfaces needs `<InternalsVisibleTo Include="DynamicProxyGenAssembly2" />` in the production project.
- Testcontainers for relational and other provider-backed integration tests, with Respawn (Apache-2.0) to reset data between tests. EF Core InMemory is not a relational substitute.
- `WebApplicationFactory<TProgram>` for HTTP pipeline tests.
- `FakeTimeProvider` (`Microsoft.Extensions.Time.Testing`) for time-dependent behavior; no hand-written fixed-time `TimeProvider` subclasses.
- ArchUnitNET for architecture tests.

`global.json` selects the platform (see [project setup](project-setup.md#build-configuration)); each test project is an executable:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="xunit.v3.mtp-v2" />
    <PackageReference Include="AwesomeAssertions" />
    <PackageReference Include="Microsoft.Extensions.TimeProvider.Testing" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\src\<Name>.<App>\<Name>.<App>.csproj" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Xunit" />
  </ItemGroup>
</Project>
```

## Projects and test levels

Split tests into `*.Tests.Unit`, `*.Tests.Integration`, and `*.Tests.Architecture` projects, created only when they have meaningful tests. Each level owns its failure modes:

- **Unit**: domain rules, normalization, state transitions, validators, isolated application behavior.
- **Integration**: EF Core mappings, queries, constraints, transactions, and migrations against the real provider; routing, authentication, binding, serialization, error format, and status translation through `WebApplicationFactory`; outbound clients against stubbed HTTP.
- **Architecture**: project references, dependency direction (including the `DbContext` exception), and structural rules.

## Structure and naming

Mirror production feature paths inside each test project. Keep feature-specific builders and fixtures beside their tests; put reusable host factories, database setup, and stubs in a `TestSupport` folder.

Name test classes after the type, feature, or endpoint under test with a `Tests` suffix. Name methods `Operation_outcome_when_condition`, keeping only the condition that distinguishes the behavior: `Create_returns_error_when_code_is_blank`, `Post_persists_foo_and_returns_created`. Disable CA1707 and the `Async` suffix rule for test projects.

Separate the arrange, act, and assert phases with blank lines rather than phase comments. One primary act per focused test; several assertions on one outcome are fine. Assert expected errors by their catalog code, not their message.

## Doubles and data

Prefer real deterministic collaborators and small behavior-focused fakes. Use a mock to verify a meaningful external interaction, such as the request sent to a client or a published message; otherwise assert observable state. Create mutable doubles fresh per test.

Builders create valid objects by default and each test overrides only scenario-relevant values; make invalid inputs deliberate and visibly named. Use fixed deterministic values. Generate identifiers only for required uniqueness, and derive them from the test case or a central generator rather than `Guid.NewGuid()` or the current time.

## Asynchronous and database tests

Pass `TestContext.Current.CancellationToken` to cancellable calls in tests (xUnit analyzer xUnit1051 flags the rest).

Synchronize on the actual event or state (`TaskCompletionSource<T>`, channels, instrumented dependencies) rather than arbitrary delays. When nothing direct is available, poll the observable result at a short interval with a bounded timeout. Every wait has a timeout as a safety guard.

Integration test projects own a collection-scoped database container that migrates once. Reset application tables before each test while preserving migration history. Classes sharing that database share an xUnit collection so they run serially; unrelated collections stay parallel. Create factories, clients, and contexts per test, through fixture helpers so connection settings stay consistent.

## Commands

```sh
dotnet test --project path/to/Tests.csproj --filter-method "Namespace.Type.Method"
dotnet test --project path/to/Tests.csproj --filter-class "Namespace.Type"
dotnet test --project path/to/Tests.csproj
```
