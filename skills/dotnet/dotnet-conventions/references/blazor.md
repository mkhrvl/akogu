# Blazor conventions

## Render modes

A Blazor Web App for internal users defaults to Interactive Server, set once at the root with `@rendermode="PageRenderMode"`, where `PageRenderMode` is `HttpContext.AcceptsInteractiveRouting() ? InteractiveServer : null`. Pages that must write the HTTP response, such as Identity sign-in pages issuing cookies, opt out with `[ExcludeFromInteractiveRouting]` and render statically.

Prerendering runs a page's initialization twice, once on the server render and again when the circuit starts. A page that loads data in `OnInitializedAsync` persists it across the two with `[PersistentState]` on the property and loads only when nothing was restored (`Items ??= await LoadAsync()`), or disables prerendering for that page when the double load matters and the content needs no server render.

## Placement

Razor UI lives under `Components`, separate from backend slices: routable pages in `Components/Pages/<Area>`, organized by the subject they operate on rather than URL nesting; non-routable UI and Blazor-only support types in `Components/<Area>`; only UI proven across areas in `Components/Shared`. Components depend on `Features`, authorization, and domain vocabulary; backend code never depends on `Components`, and architecture tests enforce that direction.

Components call Query and Command handlers directly through dependency injection ([architecture](architecture.md#transport-independent-operations)). An Interactive Server UI never calls its own application's HTTP endpoints. Use `Edit` in UI names (`FooEditorDialog`) while the handler keeps its operation verb (`UpdateFooCommand`).

## Component files

Keep a purely presentational component in one `.razor` file when its `@code` block holds only parameters and side-effect-free display members. Move code to a matching `.razor.cs` partial class when the component uses injected services, lifecycle overrides, mutable state, event handlers, asynchronous work, navigation, or handler calls. Components are framework-activated, the exception to constructor injection ([C#](csharp.md#constructors-and-dependencies)): declare dependencies as `[Inject] private IFoo Foo { get; set; } = null!;` in the partial class rather than `@inject`. Directives (`@page`, `@attribute`, `@implements`, `@typeparam`) stay in `.razor`.

The `.razor` file owns rendered structure: control flow (`@if`, `@foreach`, `@switch`), bindings, and concise expressions. Move state preparation in `@{ }` blocks and multi-statement event lambdas into methods.

Razor passes an unprefixed value to a `string` parameter as literal text: `Reason="_reason"` sends the text `_reason`. Prefix C# expressions with `@` at every string-parameter boundary (`Reason="@_reason"`), or use `@bind-Value` where the component supports two-way binding.

## Lifetime and data access

A circuit's DI scope lasts as long as the user's connection, so a scoped service injected into components is shared by every event the circuit handles, and their asynchronous continuations interleave. Never inject a `DbContext` into a component or hold one across events; handlers use `IDbContextFactory<T>` and create one context per operation ([persistence](persistence.md#access)).

`HttpContext` and `IHttpContextAccessor` are valid only during static server rendering. Interactive components read the user through `AuthenticationStateProvider`.

A component that starts asynchronous work owns a `CancellationTokenSource`, passes its token to handler calls, and cancels and disposes it in `Dispose`, so navigating away stops the work. Marshal updates from timers or external events with `InvokeAsync(StateHasChanged)`, and unsubscribe in `Dispose`.

An unhandled exception in an interactive component ends the user's circuit. Expected failures arrive as `ErrorOr` results and render as error states; unexpected ones are logged and shown without exception details.

## Authorization

Routable pages declare their policy with `[Authorize(Policy = ...)]`; the page, like an endpoint, is the security boundary. `AuthorizeView` and cached permission checks control presentation only. Resolve a permission that shapes a page's layout once before first render, because `AuthorizeView` clears its result during each re-evaluation and makes authorized controls flicker in frequently re-rendered content.

A circuit holds its principal for its whole lifetime, so a route check made at navigation can be stale by the time the user acts. Immediately before each permission-controlled mutation, evaluate the operation's policy against the circuit's current principal through one scoped user-context service, and derive the audited actor from that same principal only after authorization succeeds. Handlers receive the actor explicitly and never read Blazor authentication state. Keep the template's revalidating authentication state provider so deactivated users lose access within its interval.

## Forms and actions

Use `EditForm` with an explicit `EditContext` and a `ValidationMessageStore`. Map each `Validation` error from a handler result to its field through the error's `name` metadata (`store.Add(editContext.Field(name), error.Description)`), and show errors not tied to a field in a form-level alert. Disable submission while it is in progress and ignore repeated activation.

Compute dirty state from normalized field values rather than `EditContext.IsModified()`, which stays set after an edit restores the original value. Protect a changed form from accidental navigation, while an explicit Cancel discards.

Start a server-generated download with a same-origin link carrying `download` and `data-enhance-nav="false"`, so the browser handles the response without replacing the page or ending the circuit; `NavigationManager.NavigateTo(url, forceLoad: true)` tears the circuit down.

Filter, sort, and page large lists in the database through the handler, never in the component.

## Testing

Business rules live in handlers and domain types, where unit and integration tests cover them. Verify UI flows in a real browser with the `playwright-cli` skill. Add bUnit (MIT) component tests only for component logic those tests cannot reach.
